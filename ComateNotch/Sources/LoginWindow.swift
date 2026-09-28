import AppKit
import WebKit

/// 登录窗口：由 HUD 自己完成一次 WPS 官方登录，把 wps_sid 记进内存（不落盘、不碰钥匙串）。
///
/// 两个设计取舍：
/// - **独立 NSWindow，不用 SwiftUI sheet**：HUD 的面板是非激活 borderless NSPanel，其中弹不出 sheet
///   （「关于」窗口也是因此走独立窗口）。
/// - **登录页跑在非持久（内存）store 上**：登录产生的 cookie 不落盘（不需要免登录）。
///   注意：换 store **不能**避免登录时 WebKit 自己创建 `WebCrypto.master` 钥匙串条目
///   （实测内存态 store 一样建，见 `AuthSession` 顶部注释），该条目与授权弹框的关系见 AGENTS.md。
/// - **轮询兜底**：内存态 store 上的 `cookiesDidChange` 通知不能作为唯一触发源，
///   所以窗口活着时每 2 秒自己查一次登录页那口 store（否则会出现「页面已登录、HUD 永远不知道」）。
///
/// 登录成功的判据是「真的打通了 HUD 依赖的两条链路」，而不是「cookie 里出现了 wps_sid」——
/// 后者会出现「看着登录成功、凭据其实不可用」的假成功。
final class LoginWindowController: NSObject, NSWindowDelegate, WKHTTPCookieStoreObserver {

    static let shared = LoginWindowController()

    private static let loginURL = URL(string: "https://comate.wps.cn/web/")!
    private static let windowWidth: CGFloat = 460
    /// comate.wps.cn/web 的登录页在视口高 <600pt 时自身布局会塌（绿色主登录按钮被压成一条），
    /// 实测阈值 600pt。窗口正文顶部说明区占 78pt，故按 WebView ≈740pt 定窗口高度。
    private static let windowHeight: CGFloat = 820
    /// 允许缩小，但下限保证 WebView ≥620pt，不越过登录页的 600pt 塌陷线
    private static let windowMinHeight: CGFloat = 700
    /// 校验失败后的重试次数：登录页回跳需要时间，sid 可能先到、权限后到
    private static let maxAttempts = 3

    private var window: NSWindow?
    private var webView: WKWebView?
    private var statusLabel: NSTextField?
    private var verifying = false
    private var finished = false
    private var attempt = 0
    private var onSuccess: (() -> Void)?
    /// 校验在飞时又来了新的 cookie（页面连续写）→ 记下来，本轮跑完立刻再跑一次，
    /// 否则「最后一次写 cookie = sid 落地」那一次可能被丢弃。
    private var pendingStore: WKHTTPCookieStore?
    /// 轮询兜底：内存态 store 上的 cookiesDidChange 通知实测不可靠（登录完成后一次都没触发），
    /// 只靠它会出现「页面已登录、HUD 却永远不知道」。
    private var pollTimer: Timer?
    private var lastStallLogAt: Date?
    private var didLogSid = false

    private override init() { super.init() }

    // MARK: - 对外入口

    /// 打开登录流程。先看内存里有没有本次运行已登录的凭据（present 前刚登过就不重复弹窗）：有就直探测，
    /// 通了立刻回调、不弹窗（用户观感是「点一下就恢复」）；没有或不通才真的开窗。
    func present(onSuccess: @escaping () -> Void) {
        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        self.onSuccess = onSuccess
        self.finished = false
        self.attempt = 0
        self.didLogSid = false
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            if let sid = AuthSession.shared.currentSid(forceRefresh: true), Self.probe(sid: sid) {
                DispatchQueue.main.async {
                    AuthSession.shared.markOK()
                    self.finished = true
                    self.onSuccess?()
                }
                return
            }
            DispatchQueue.main.async { self.openWindow() }
        }
    }

    /// 菜单与面板提示共用的入口：登录成功后立刻恢复云端数据
    func present(refreshing store: ComateStore) {
        present { [weak store] in store?.refreshAfterLogin() }
    }

    /// 登录成功的判据：真的拿这把 sid 打通 HUD 依赖的两条链路。
    /// 一条是 o.wpsgo.com（身份 / 上报），一条是 comate.wps.cn（未读 / 额度）。任一不通都不算成功。
    private static func probe(sid: String) -> Bool {
        let identityOK = UserIdentity.shared.current(sid: sid, forceRefresh: true) != nil
        var usageOK = false
        if case .ok = UsageAPI.fetchLimits(sid: sid) { usageOK = true }
        return identityOK && usageOK
    }

    // MARK: - 窗口

    private func openWindow() {
        guard window == nil else { return }

        // 登录页专用 webview：非持久 store（内存态）—— WebKit 用内存主密钥，登录链路不碰钥匙串。
        // 凭据拿到后只记内存（AuthSession.adopt），不落盘、不镜像。
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        self.webView = webView

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
                                                  width: Self.windowWidth, height: Self.windowHeight),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "登录 WPS 账号"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = NSSize(width: Self.windowWidth, height: Self.windowMinHeight)
        // 固定落在真正的主显示器（NSScreen.screens[0] = 菜单栏所在屏）。
        // window.center() 用的是 NSScreen.main（当前有焦点的屏），用户在副屏工作时
        // 登录窗会跑到副屏；而登录窗是「整个 HUD 的前置引导」，应当出现在主屏。
        if let primary = NSScreen.screens.first {
            let visible = primary.visibleFrame
            window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2,
                                         y: visible.midY - window.frame.height / 2))
        } else {
            window.center()
        }

        let tip = Self.makeLabel(
            "登录后 HUD 才能显示未读消息与额度用量。\nHUD 只保存本次登录的凭证，不会读取你的文档内容。",
            size: 11.5, color: .secondaryLabelColor)
        let status = Self.makeLabel("请在下方完成登录（扫码或账号密码）", size: 11.5, color: .secondaryLabelColor)
        self.statusLabel = status

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        webView.translatesAutoresizingMaskIntoConstraints = false
        for view in [tip, status, separator, webView] {
            window.contentView?.addSubview(view)
        }
        guard let content = window.contentView else { return }
        NSLayoutConstraint.activate([
            tip.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            tip.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            tip.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            status.topAnchor.constraint(equalTo: tip.bottomAnchor, constant: 7),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            separator.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 13),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            webView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        self.window = window
        // 快路径：cookie 一变就试着校验（登录走完回跳时 wps_sid 会落进来）
        webView.configuration.websiteDataStore.httpCookieStore.add(self)
        // 兜底：内存态 store 的变化通知不可靠（实测一次都没触发），没它就会出现
        // 「页面已经进了 Comate，HUD 却永远停在未登录」。轮询是「登录成功→自动关窗」的保障。
        startPolling(store: webView.configuration.websiteDataStore.httpCookieStore)
        webView.load(URLRequest(url: Self.loginURL))

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSLog("[ComateHUD] 已打开 WPS 登录窗口")
    }

    // MARK: - 轮询兜底

    /// 每 2 秒自己查一次登录页那口 store：拿到 wps_sid 就去校验，没有就打一次诊断日志。
    private func startPolling(store: WKHTTPCookieStore) {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.finished else { return }
            store.getAllCookies { [weak self] cookies in
                guard let self = self, !self.finished else { return }
                if AuthSession.sid(in: cookies) != nil {
                    self.scheduleVerify(store: store)
                } else {
                    self.logCookiesIfStalled(cookies)
                }
            }
        }
        // .common：菜单/面板处于事件跟踪时也继续跑，否则轮询会停掉
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// 长时间没等到 wps_sid 时把当前 cookie 名字打出来（只打名字不打印值），
    /// 用来区分「页面还没写」和「写的名字不是 wps_sid」。
    private func logCookiesIfStalled(_ cookies: [HTTPCookie]) {
        let now = Date()
        if let last = lastStallLogAt, now.timeIntervalSince(last) < 15 { return }
        lastStallLogAt = now
        let names = cookies.map { "\($0.name)@\($0.domain)" }.sorted().joined(separator: ", ")
        NSLog("[ComateHUD] 登录页暂未发现 wps_sid，当前 cookie：%@", names.isEmpty ? "(空)" : names)
    }

    private static func makeLabel(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel?.textColor = color
        statusLabel?.stringValue = text
    }

    // MARK: - 校验

    /// cookie store 变化很频繁（页面会不断写各种域的 cookie），只在「还没完成」时试一次，
    /// 真正的去重靠 verifying / finished 两个标志。（主路径其实是 2 秒轮询，这里是快路径。）
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        guard !finished else { return }
        scheduleVerify(store: cookieStore)
    }

    /// 校验流水线：从**登录页那口 store** 取 sid → 探测两条链路 → 成功则把 sid 记进内存并收尾。
    ///
    /// 凭据出生地就是登录页那口 store，所以校验直接读它；自有凭据 store 已不存在（凭据不持久化）。
    private func scheduleVerify(store loginStore: WKHTTPCookieStore) {
        guard !finished else { return }
        if verifying { pendingStore = loginStore; return }
        verifying = true
        loginStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            let sid = AuthSession.sid(in: cookies)
            if let sid = sid, !self.didLogSid {
                self.didLogSid = true
                NSLog("[ComateHUD] 已发现 wps_sid（长度 %d），开始双接口探测", sid.count)
            }
            DispatchQueue.global(qos: .utility).async {
                let ok = sid.map { Self.probe(sid: $0) } ?? false
                DispatchQueue.main.async {
                    self.verifying = false
                    if ok, let sid = sid {
                        // 凭据只记内存：不落 cookie store、不镜像、不碰钥匙串
                        AuthSession.shared.adopt(sid: sid)
                        self.finishSuccess()
                    } else if sid == nil {
                        // 还没登录：不算失败，等页面下一次写 cookie 再试
                        self.attempt = 0
                        self.setStatus("请在下方完成登录（扫码或账号密码）", color: .secondaryLabelColor)
                        self.drainPending()
                    } else {
                        self.attempt += 1
                        if self.attempt < Self.maxAttempts {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                                self?.scheduleVerify(store: loginStore)
                            }
                        } else {
                            NSLog("[ComateHUD] 双接口探测未通过（第 %d 次），凭据被服务端拒绝或权限尚未就绪",
                                  self.attempt)
                            self.setStatus("已取得登录凭证但服务端仍拒绝，请关闭窗口后重试",
                                           color: .systemOrange)
                            self.drainPending()
                        }
                    }
                }
            }
        }
    }

    private func drainPending() {
        guard let next = pendingStore else { return }
        pendingStore = nil
        scheduleVerify(store: next)
    }

    private func finishSuccess() {
        finished = true
        stopPolling()
        AuthSession.shared.markOK()
        setStatus("登录成功，正在恢复数据…", color: .systemGreen)
        NSLog("[ComateHUD] WPS 登录成功，凭据已记入内存（不落盘）")
        let callback = onSuccess
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.close()
            callback?()
        }
    }

    func close() {
        window?.close()
    }

    // MARK: - 收尾

    func windowWillClose(_ notification: Notification) {
        // 关窗 = 放弃这次登录（凭据只在内存，没成功就不会被记下）；
        // 登录成功能自动关窗，不需要用户手动关。
        stopPolling()
        releaseWebView()
        window = nil
        onSuccess = nil
        verifying = false
        attempt = 0
        pendingStore = nil
    }

    /// 关窗后卸掉登录页：实例不再复用，置空即一并释放内存 store 与页面
    /// （凭据已记进内存，不再需要这口 store）。
    private func releaseWebView() {
        guard let webView = webView else { return }
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
        webView.navigationDelegate = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        self.webView = nil
    }
}
