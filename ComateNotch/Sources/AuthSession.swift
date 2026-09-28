import Foundation

/// Comate HUD 的凭据唯一来源：**只存在内存里**的那把 wps_sid。
///
/// 两条不回退的硬约束：
/// - **不读 Keychain**：曾经 fork `/usr/bin/security` 去读 Comate 写的凭据副本，首次会弹钥匙串授权框
/// - **不写 Keychain**：任何 WebKit **持久** store 都会让 WebKit 去读钥匙串里的 WebCrypto 主密钥，
///   登录过程中会反复看到「ComateHUD 想要使用你储存在钥匙串中的…」。所以登录页跑在
///   内存态 store（内存主密钥），登录拿到的 sid 也只记在内存，不落 cookie store、不镜像、不持久化
///
/// 代价与口径：App 退出（或用户退出登录）后凭据即失效，下次启动一律按未登录处理，
/// 由 AppDelegate / 面板 / 菜单引导用户重新登录。
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

    private let lock = NSLock()
    /// 本次运行期间拿到的 sid。**只存内存**：App 退出即失效，下次启动按未登录处理。
    private var sessionSid: String?
    private var didStart = false

    private init() {}

    // MARK: - 启动

    /// 启动时调用一次（主线程）。凭据只在内存里，冷启动必然为空 →
    /// 直接判未登录，由 AppDelegate / 面板 / 菜单引导用户重新登录。
    func start() {
        guard !didStart else { return }
        didStart = true
        NSLog("[ComateHUD] 凭据不持久化，启动按未登录处理")
        setStateIfUnknown(.noCredential)
    }

    // MARK: - 凭据读取

    /// 取 sid。凭据只在内存里，这里不涉及任何 IO，线程安全。
    ///
    /// `forceRefresh` 保留：调用方用它表达「服务端刚拒过这把凭据」。内存凭据没有
    /// 「重读换一把」的可能，重读拿到的就是同一把 —— 调用方据此判定重试没有意义。
    func currentSid(forceRefresh: Bool = false) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return sessionSid
    }

    /// 登录成功后由 LoginWindow 写入内存凭据。只接受合法 sid，非法值忽略。
    func adopt(sid: String) {
        guard Self.isValidSid(sid) else {
            NSLog("[ComateHUD] 登录返回的 sid 非法，忽略")
            return
        }
        lock.lock()
        sessionSid = sid
        lock.unlock()
        NSLog("[ComateHUD] 已记录本次运行的登录凭据（仅内存）")
        setState(.ok)
    }

    /// 从一组 cookie 里取 HUD 用的那把 sid。登录页与自己那口 store 共用这一处判定。
    static func sid(in cookies: [HTTPCookie]) -> String? {
        cookies.first { $0.name == sidCookieName && !$0.value.isEmpty }?.value
    }

    /// cookie 值会拼进 `Cookie` 请求头，含换行/控制字符时可能注入额外 HTTP 头。
    /// 来源是自家登录页，风险低，但校验很便宜。
    static func isValidSid(_ sid: String) -> Bool {
        guard !sid.isEmpty, sid.count <= 512 else { return false }
        return sid.allSatisfy { c in
            (c.isLetter && c.isASCII) || (c.isNumber && c.isASCII) || "-_".contains(c)
        }
    }

    // MARK: - 状态迁移

    /// 凭据确认可用（登录成功 / 真实请求成功）
    func markOK() {
        setState(.ok)
    }

    /// 服务端拒绝（401/403）：标记为过期，保留内存里的 sid ——
    /// 可能只是服务端瞬时拒绝；真要重登时 LoginWindow 会覆盖它。
    func markExpired() {
        setState(.expired)
    }

    /// 退出登录：丢掉内存凭据，回到未登录态。
    func signOut(completion: (() -> Void)? = nil) {
        lock.lock()
        sessionSid = nil
        lock.unlock()
        setState(.noCredential)
        NSLog("[ComateHUD] 已退出登录，内存凭据已丢弃")
        DispatchQueue.main.async { completion?() }
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
