import Foundation
import WebKit

/// Comate HUD 的凭据唯一来源：本 App 内嵌 WKWebView 的 cookie store。
///
/// 为什么不再读 Comate 写在 Keychain 里的 wps_sid：那是**别的 App 的凭据副本** ——
/// 读它要 fork `/usr/bin/security`（别人机器上首次会弹钥匙串授权框，被拒就等于凭空没有凭据），
/// 而 WPS 何时轮换、是否回写都不由我们掌控，凭据坏了也没人知道。
/// 现在改成 HUD 自己用 WKWebView 走一次官方登录：凭据存在自己的 cookie store 里，
/// 自己读取、自己检测失效、自己引导重登 —— 全链路可自愈。
///
/// 实测约束（决定了这个类的形状）：
/// - **必须存在一个 WKWebView 实例才读得到 cookie**：没有实例时 `getAllCookies` 恒返回空集
/// - cookie 按 bundle id 隔离，读不到 Safari / WPS Office / Comate 桌面端的登录态
/// - 常驻一个「未加载任何页面」的实例：主进程 +21MB，不额外拉起辅助进程；
///   反复创建/销毁会让 WebKit 反复起停辅助进程，故常驻一个，登录窗口复用它，全 App 只有一份
/// - `getAllCookies` 是异步 API，这里用信号量同步等待：会等 XPC，**必须在后台队列调用**
final class AuthSession {
    static let shared = AuthSession()

    /// 凭据状态。`unknown` 只在启动后极短时间内出现（首次判定完成前）
    enum State {
        case unknown
        case noCredential
        case ok
        case expired
    }

    /// 状态变化回调，主队列触发，且只在状态真的变化时触发
    var onStateChange: ((State) -> Void)?

    private(set) var state: State = .unknown

    private static let sidCookieName = "wps_sid"
    /// 读 cookie 的超时：正常在毫秒级返回，超时说明 WebKit 辅助进程异常
    private static let readTimeout: TimeInterval = 6

    /// 首次判定的重试节奏。冷启动时 WebKit 的 cookie store 可能尚未就绪，
    /// 第一次 getAllCookies 会空手而归（与紧接着的第二次读取结果不一致）。
    /// 直接判「无凭据」会让面板提示未登录、菜单却显示已登录，所以重试几次再下结论。
    static let initialReadRetryDelays: [TimeInterval] = [0.3, 0.7, 1.5]

    private let lock = NSLock()
    private let webViewLock = NSLock()
    private var cachedSid: String?
    private var webView: WKWebView?
    private var didStart = false

    private init() {}

    // MARK: - 启动

    /// 启动时调用一次（主线程）：备好常驻 webview，并异步做首次凭据判定。
    func start() {
        guard !didStart else { return }
        didStart = true
        _ = ensureWebView()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            // 这里只能判定「有没有凭据」；「凭据还管不管用」交给第一次真实请求（401/403 会翻成 .expired）
            // 且只能用低权威的 setStateIfUnknown：探测慢的时候，真实请求可能已经先给出结论了
            if self.currentSid() != nil {
                self.setStateIfUnknown(.ok)
                return
            }
            NSLog("[ComateHUD] 首次读凭据未命中，按冷启动时序重试")
            for delay in Self.initialReadRetryDelays {
                Thread.sleep(forTimeInterval: delay)
                if self.currentSid(forceRefresh: true) != nil {
                    NSLog("[ComateHUD] 重试后拿到凭据，判定为已登录")
                    self.setStateIfUnknown(.ok)
                    return
                }
            }
            NSLog("[ComateHUD] 重试后仍无凭据，判定为未登录")
            self.setStateIfUnknown(.noCredential)
        }
    }

    // MARK: - 凭据读取

    /// 取 sid（默认读内存缓存）。线程安全，**必须在后台队列调用**。
    ///
    /// `forceRefresh` 用于凭据被服务端拒后的重读：重读拿到的值与旧值相同，
    /// 就说明这把凭据换不掉，调用方据此判定「重试没有意义」。
    func currentSid(forceRefresh: Bool = false) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if !forceRefresh, let cached = cachedSid { return cached }
        guard let fresh = readSidFromCookieStore(), Self.isValidSid(fresh) else { return nil }
        cachedSid = fresh
        return fresh
    }

    /// 同步读 cookie store。不判有效性，只负责取出来。
    private func readSidFromCookieStore() -> String? {
        let store = ensureWebView().configuration.websiteDataStore.httpCookieStore
        var found: String?
        let semaphore = DispatchSemaphore(value: 0)
        store.getAllCookies { cookies in
            found = cookies.first { $0.name == Self.sidCookieName && !$0.value.isEmpty }?.value
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + Self.readTimeout) == .timedOut {
            NSLog("[ComateHUD] 读取 cookie store 超时，按无凭据处理")
            return nil
        }
        return found
    }

    /// cookie 值会拼进 `Cookie` 请求头，含换行/控制字符时可能注入额外 HTTP 头。
    /// 来源是自家 cookie store，风险低，但校验很便宜。
    static func isValidSid(_ sid: String) -> Bool {
        guard !sid.isEmpty, sid.count <= 512 else { return false }
        return sid.allSatisfy { c in
            (c.isLetter && c.isASCII) || (c.isNumber && c.isASCII) || "-_".contains(c)
        }
    }

    // MARK: - 常驻 webview

    /// 全 App 唯一的那份 WKWebView。登录窗口直接复用它（见 LoginWindow），避免两份实例两份内存。
    var cookieWebView: WKWebView { ensureWebView() }

    private func ensureWebView() -> WKWebView {
        webViewLock.lock()
        if let existing = webView {
            webViewLock.unlock()
            return existing
        }
        webViewLock.unlock()

        // 建 WKWebView 必须在主线程
        var made: WKWebView?
        let make = {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            made = WKWebView(frame: .zero, configuration: config)
        }
        if Thread.isMainThread { make() } else { DispatchQueue.main.sync(execute: make) }

        webViewLock.lock()
        if webView == nil { webView = made }
        let result = webView!
        webViewLock.unlock()
        return result
    }

    // MARK: - 状态迁移

    /// 凭据确认可用（登录成功 / 真实请求成功）
    func markOK() {
        setState(.ok)
    }

    /// 服务端拒绝（401/403）：清缓存，让下一次读取重新去 cookie store 取。
    /// 不清空 cookie 本身 —— 凭据可能只是服务端瞬时拒绝，或者用户马上要重登。
    func markExpired() {
        lock.lock()
        cachedSid = nil
        lock.unlock()
        setState(.expired)
    }

    /// 退出登录：清掉自家 cookie store 里的 cookie，回到未登录态。
    /// 用 removeData 而不是逐个 delete：HUD 的 store 只为 WPS 登录而存在，整片清掉更彻底。
    func signOut(completion: (() -> Void)? = nil) {
        let store = ensureWebView().configuration.websiteDataStore
        store.removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: .distantPast) {
            DispatchQueue.main.async {
                self.lock.lock()
                self.cachedSid = nil
                self.lock.unlock()
                self.setState(.noCredential)
                NSLog("[ComateHUD] 已退出登录，清空本地登录凭据")
                completion?()
            }
        }
    }

    private func setState(_ new: State) {
        let apply = { [weak self] in
            guard let self = self, self.state != new else { return }
            self.state = new
            self.onStateChange?(new)
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    /// 启动探测专用：只在「还没有结论」时写入。
    /// 探测只回答「cookie store 里现在有没有 cookie」，权威性低于真实请求的结论（markOK / markExpired）。
    /// 探测较慢时（WebKit 冷启动、XPC 迟延），期间第一次真实请求已经能下结论了 ——
    /// 这份迟到的无凭据结论一旦覆盖掉它，面板就会提示未登录、菜单却显示已登录。
    private func setStateIfUnknown(_ new: State) {
        let apply = { [weak self] in
            guard let self = self, Self.probeCanApply(currentState: self.state) else { return }
            self.state = new
            self.onStateChange?(new)
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    /// 启动探测的结论能不能落地：只有还没结论时才行
    static func probeCanApply(currentState: State) -> Bool {
        currentState == .unknown
    }
}
