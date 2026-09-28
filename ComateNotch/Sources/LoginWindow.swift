import AppKit
import WebKit

/// 登录窗口：由 HUD 自己完成一次 WPS 官方登录，把 wps_sid 落到自己的 cookie store 里。
///
/// 两个设计取舍：
/// - **独立 NSWindow，不用 SwiftUI sheet**：HUD 的面板是非激活 borderless NSPanel，其中弹不出 sheet
///   （「关于」窗口也是因此走独立窗口）。
/// - **复用 AuthSession 的常驻 WKWebView**：全 App 只有一份实例，登录产生的 cookie 直接落在
///   凭据来源那口 store 里，不需要在两份 store 之间搬运；关窗时只清空页面，实例留着继续读 cookie。
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

        let webView = AuthSession.shared.cookieWebView
        self.webView = webView

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
                                                  width: Self.windowWidth, height: Self.windowHeight),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "登录 WPS 账号"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = NSSize(width: Self.windowWidth, height: Self.windowMinHeight)
        window.center()

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

    /// cookie store 变化很频繁（页面会不断写各种域的 cookie），这里只在「还没完成」时试一次，
    /// 真正的去重靠 verifying / finished 两个标志。
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        scheduleVerify()
    }

    /// 单条校验流水线：读 cookie → 探测两条链路 → 成功收尾 / 失败重试
    private func scheduleVerify() {
        guard !verifying, !finished else { return }
        verifying = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            // 这里要的是「cookie 里现在是什么」，所以强制重读，不走内存缓存
            let sid = AuthSession.shared.currentSid(forceRefresh: true)
            let ok = sid.map { Self.probe(sid: $0) } ?? false
            let hadSid = (sid != nil)
            DispatchQueue.main.async {
                self.verifying = false
                if ok {
                    self.finishSuccess()
                    return
                }
                self.attempt += 1
                if self.attempt < Self.maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.scheduleVerify()
                    }
                } else if hadSid {
                    self.setStatus("已取得登录凭证但服务端仍拒绝，请关闭窗口后重试",
                                   color: .systemOrange)
                } else {
                    self.setStatus("请在下方完成登录（扫码或账号密码）", color: .secondaryLabelColor)
                }
            }
        }
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
        releaseWebView()
        window = nil
        onSuccess = nil
        verifying = false
        attempt = 0
    }

    /// 关窗后把 webview 从窗口摘下来并清空页面：实例必须留着（读 cookie 靠它），
    /// 但不能让 WPS 页面挂在后台继续跑 JS 与轮询。
    private func releaseWebView() {
        guard let webView = webView else { return }
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
        webView.removeFromSuperview()
        self.webView = nil
    }
}
