import AppKit
import WebKit

/// 登录窗口：由 HUD 自己完成一次 WPS 官方登录，把 wps_sid 落到自己的 cookie store 里。
///
/// 两个设计取舍：
/// - **独立 NSWindow，不用 SwiftUI sheet**：HUD 的面板是非激活 borderless NSPanel，其中弹不出 sheet
///   （「关于」窗口也是因此走独立窗口）。
/// - **登录页跑在非持久（内存）store 上**：WebKit 只在持久 store 里才需要读钥匙串中的
///   `WebCrypto Master Key`；非持久 store 用内存里的主密钥。登录过程里反复弹的
///   「ComateHUD 想要使用你储存在钥匙串中的…」就是持久 store 触发的，换内存 store 后
///   登录链路不再碰钥匙串。代价是 cookie 要先镜像进自有凭据 store（见 absorbCookies）。
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

    private override init() { super.init() }

    // MARK: - 对外入口

    /// 打开登录流程。先看自家 cookie store 里有没有现成可用的凭据：有就直接探测，
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

        // 登录页专用 webview：非持久 store（内存态），不与自有凭据 store 共用；
        // 登录产生的 cookie 由 cookiesDidChange 镜像进自有 store。
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
        // cookie 一变就试着校验：登录走完回跳时 wps_sid 会落进来
        webView.configuration.websiteDataStore.httpCookieStore.add(self)
        webView.load(URLRequest(url: Self.loginURL))

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSLog("[ComateHUD] 已打开 WPS 登录窗口")
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
    /// 真正的去重靠 verifying / finished 两个标志。
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        guard !finished else { return }
        scheduleVerify(store: cookieStore)
    }

    /// 校验流水线：从**登录页那口 store** 取 sid → 探测两条链路 → 成功则先把 cookie 镜像进
    /// 自有凭据 store（重启后免登录靠它）再收尾。
    ///
    /// 为什么读登录页那口 store 而不是自有 store：登录页跑在内存态 store 上，sid 只落在
    /// 这口 store 里；镜像落地是异步的，拿镜像后的值校验会误判「登录失败」（窗口不关、面板显示未登录）。
    private func scheduleVerify(store loginStore: WKHTTPCookieStore) {
        guard !finished else { return }
        if verifying { pendingStore = loginStore; return }
        verifying = true
        loginStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            let sid = AuthSession.sid(in: cookies)
            DispatchQueue.global(qos: .utility).async {
                let ok = sid.map { Self.probe(sid: $0) } ?? false
                DispatchQueue.main.async {
                    self.verifying = false
                    if ok, sid != nil {
                        // 先确保凭据真的进了自有 store，再宣布成功（否则重启后免登录会“莫名失效”）
                        AuthSession.shared.absorbCookies(from: loginStore) { allPersisted in
                            if !allPersisted {
                                NSLog("[ComateHUD] 登录凭据镜像未完全落地，重启后可能需重新登录")
                            }
                            self.finishSuccess()
                        }
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
        AuthSession.shared.markOK()
        setStatus("登录成功，正在恢复数据…", color: .systemGreen)
        NSLog("[ComateHUD] WPS 登录成功，凭据已写入 HUD 自有 cookie store")
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
        // 用户可能在登录成功后才手动关窗（比如弹窗没自动关）：关窗前兜底镜像一次，
        // 否则这口内存 store 随实例释放，辛苦登的凭据就丢了。
        if let store = webView?.configuration.websiteDataStore.httpCookieStore {
            AuthSession.shared.absorbCookies(from: store) { [weak self] _ in
                self?.releaseWebView()
            }
        } else {
            releaseWebView()
        }
        window = nil
        onSuccess = nil
        verifying = false
        attempt = 0
        pendingStore = nil
    }

    /// 关窗后卸掉登录页：登录页跑在内存态 store 上、实例不再复用，
    /// 置空即一并释放内存 store 与页面（凭据已镜像进自有 store，读 cookie 走常驻 webview）。
    private func releaseWebView() {
        guard let webView = webView else { return }
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
        webView.navigationDelegate = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        self.webView = nil
    }
}
