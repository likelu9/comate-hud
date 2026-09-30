import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var backdropPanel: NotchBackdropPanel?
    private var floatingPanel: FloatingPanel?
    private var store = ComateStore()
    private var screenObserver: NSObjectProtocol?
    /// 本进程是否真的接管了 HUD。重复实例在启动检查后立刻退出，
    /// 此时绝不能去 flush 活跃上报桶 —— 桶归已在运行的那个实例所有，重复 flush 会重复上报
    private var didBecomePrimary = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 单实例：已在运行则请它把面板重新置前后自己退出（避免两份 HUD 叠加、双份定时器与上报）
        if let other = Self.otherRunningInstance() {
            DistributedNotificationCenter.default().postNotificationName(
                .hudShowRequest, object: nil, userInfo: nil, deliverImmediately: true)
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        didBecomePrimary = true

        // 代码身份一变就重置 WebKit 的 WebCrypto 主密钥钥匙串条目。
        // 必须在任何 WKWebView 被创建之前：条目 partition 记的是创建它的那次构建的 cdhash，
        // 不重置就会在每次重建/发版后被 securityd 判 `ACL partition mismatch` 并弹授权框（见 WebCryptoKeyReset）
        WebCryptoKeyReset.resetIfIdentityChanged()

        // 用户重复双击 App 时，由新实例发来置前请求；按当前模式重新置前面板即可
        // （switchDisplayMode 幂等，不会重建窗口）。观察者随进程存活，不需要移除
        _ = DistributedNotificationCenter.default().addObserver(
            forName: .hudShowRequest, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.switchDisplayMode(self.store.displayMode)
        }

        let panel = NotchPanel(screen: targetNotchScreen())
        self.panel = panel

        // 监听外接显示器热插拔：屏幕数量/排列变化时重新解析目标屏并重定位。
        // 与用户手动换屏走同一条路径 —— 以前只挪窗口 frame，notch 几何会停在旧屏上
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.retargetNotchPanel()
                self?.floatingPanel?.repositionToMainScreen()
            }
        }

        // 静态托底窗口：固定收起态尺寸，置于主面板下层，不参与动效
        rebuildNotchBackdrop(collapsedFrame: panel.collapsedFrame(), visible: true)

        panel.contentView = makeNotchChrome(for: panel,
                                            initialExpanded: CommandLine.arguments.contains("--expanded"))
        store.start()
        offerLoginOnLaunch()
        // 首次启动默认开启开机自启（仅一次，之后完全由菜单里的开关控制）
        LaunchAtLogin.applyDefaultOnFirstLaunch()
        // 应用上次保存的显示模式（否则启动后总是显示刘海面板）
        switchDisplayMode(store.displayMode)

        // 本地预览：COMATE_HUD_PREVIEW_UPDATE_STATE 命中时直接把更新窗打开（见 ComateStore）
        if store.previewWindowStateRequested { presentUpdateWindow() }
    }

    // MARK: - 刘海面板几何

    /// 当前该贴哪块屏：用户选择的那块（拔了就临时回退主屏，选择本身保留）
    private func targetNotchScreen() -> NSScreen? {
        let options = NotchPanel.screenOptions()
        guard let hit = NotchScreenTarget.resolve(saved: store.notchScreenID, options: options),
              let screen = NSScreen.screens.first(where: { $0.cmDisplayID == hit.id }) else {
            return NSScreen.main ?? NSScreen.screens.first
        }
        return screen
    }

    /// 用户从菜单指定刘海屏幕（nil = 跟随主屏）：存偏好后立即换屏
    private func selectNotchScreen(_ id: UInt32?) {
        guard store.notchScreenID != id else { return }
        store.notchScreenID = id
        retargetNotchPanel()
    }

    /// 换屏（用户选择 / 显示器热插拔）：重算几何并重建烘死几何的那层视图。
    /// wingWidth / notchHeight / expandedWidth 都是构造期传入 NotchRootView 的，
    /// 只挪窗口 frame 会得到宽度与黑罩高度都对不上的面板
    private func retargetNotchPanel() {
        guard let panel = panel else { return }
        guard panel.retarget(to: targetNotchScreen()) else { return }
        // 换屏后鼠标已不在面板上，继续展开会变成一块卡在新屏上的面板
        store.setPanelExpanded(false)
        panel.contentView = makeNotchChrome(for: panel, initialExpanded: false)
        rebuildNotchBackdrop(collapsedFrame: panel.collapsedFrame(),
                             visible: store.displayMode == .notchHUD)
    }

    /// 静态托底窗口：跟随面板几何重建（换屏后宽度可能不同，不能只挪窗口）
    private func rebuildNotchBackdrop(collapsedFrame: NSRect, visible: Bool) {
        let old = backdropPanel
        let backdrop = NotchBackdropPanel(collapsedFrame: collapsedFrame)
        backdropPanel = backdrop
        if visible { backdrop.orderFrontRegardless() }
        old?.orderOut(nil)
    }

    /// 刘海面板的内容层：菜单宿主 + SwiftUI 内容。启动与换屏共用，两处构造参数不会漂移
    private func makeNotchChrome(for panel: NotchPanel, initialExpanded: Bool) -> HUDMenuHostView {
        let geo = panel.notch
        // 菜单宿主：右键与设置按钮共用同一份菜单（HUDContextMenu），两种显示模式只换窗口
        let container = HUDMenuHostView(frame: NSRect(x: 0, y: 0,
                                                      width: panel.expandedWidth,
                                                      height: panel.hostingHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.menuBuilder = HUDContextMenu(
            store: store,
            onSwitchMode: { [weak self] mode in self?.switchDisplayMode(mode) },
            onShowMainWindow: { [weak self] in
                self?.store.openComateApp()
                NSApp.activate(ignoringOtherApps: true)
            },
            onShowSettings: { [weak self] page in self?.presentSettings(page) },
            onShowUpdate: { [weak self] in
                guard let store = self?.store else { return }
                UpdateWindowController.shared.present(store: store, actions: .standard(store: store))
            },
            onLogin: { [weak self] in self?.presentLogin() },
            onSignOut: { AuthSession.shared.signOut() },
            screenOptions: { NotchPanel.screenOptions() },
            onSelectScreen: { [weak self] id in self?.selectNotchScreen(id) })

        let view = NotchRootView(
            store: store,
            initialExpanded: initialExpanded,
            onExpandChange: { [weak panel, weak store] isExpanded, height in
                store?.setPanelExpanded(isExpanded)
                if isExpanded { panel?.animateToExpanded(height: height) }
                else { panel?.animateToCollapsed() }
            },
            wingWidth: panel.wingWidth,
            notchHeight: geo.notchHeight,
            expandedWidth: panel.expandedWidth,
            canvasHeight: panel.hostingHeight,
            onExpandedHeightChange: { [weak panel] h in
                panel?.setExpandedHeightImmediate(h)
            },
            onResizeBegin: { [weak panel] maxH in
                panel?.beginLiveResize(maxHeight: maxH)
            },
            onResizeEnd: { [weak panel] h in
                panel?.setExpandedHeightImmediate(h)
            },
            onShowMenu: { [weak container] in
                ActivityReporter.shared.record(.click)
                container?.showMenu()
            }
        )
        // hostingView 固定为展开态尺寸并吸顶，不随窗口高度动画改变尺寸。
        // 否则 NSHostingView 每次窗口 resize 都要重排，且窗口变矮时内容会被
        // 推到底部（AppKit 默认底部锚定）→ 展开动画期间顶部 logo/状态灯/+ 跳动。
        // 窗口收起时超出部分由窗口自身裁剪，可见区域正好是内容顶部。
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0,
                               width: panel.expandedWidth,
                               height: panel.hostingHeight)
        // minYMargin 弹性 = 顶部边距固定 → 视图始终吸在窗口顶部
        hosting.autoresizingMask = [NSView.AutoresizingMask.minYMargin]
        container.addSubview(hosting)
        return container
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 重复实例：没接管 HUD，也就没有自己的活跃桶要发
        guard didBecomePrimary else { return }
        if let obs = screenObserver { NotificationCenter.default.removeObserver(obs) }
        // 退出前把当天的活跃桶发出去（最多等 3 秒）。发不出去也不丢：
        // 桶已落盘，下次启动会补报。
        ActivityReporter.shared.flushSync()
        store.stop()
    }

    /// 打开设置窗口。显示模式 / 刘海屏幕这两项要动窗口，由本类执行（设置窗口只写 store）
    private func presentSettings(_ page: SettingsPage) {
        SettingsWindowController.shared.present(
            page: page,
            store: store,
            actions: SettingsActions(
                switchMode: { [weak self] mode in self?.switchDisplayMode(mode) },
                selectScreen: { [weak self] id in self?.selectNotchScreen(id) },
                openUpdate: { [weak self] in self?.presentUpdateWindow() }))
    }

    /// 更新提示独立小窗：与更新检查、红点共用同一个 store
    private func presentUpdateWindow() {
        UpdateWindowController.shared.present(store: store, actions: .standard(store: store))
    }

    /// 切换显示模式。幂等：重复切到同一模式不会重建窗口（启动时也会调用一次）
    private func switchDisplayMode(_ mode: ComateStore.DisplayMode) {
        store.displayMode = mode
        switch mode {
        case .notchHUD:
            if floatingPanel != nil {
                floatingPanel?.orderOut(nil)
                floatingPanel = nil
            }
            panel?.orderFrontRegardless()
            backdropPanel?.orderFrontRegardless()
        case .floating:
            if floatingPanel == nil {
                // 宽度对齐刘海模式，两种模式面板宽度一致
                let fp = FloatingPanel(store: store,
                                       expandedWidth: panel?.expandedWidth ?? 280) { [weak self] m in
                    self?.switchDisplayMode(m)
                }
                fp.onSelectScreen = { [weak self] id in self?.selectNotchScreen(id) }
                floatingPanel = fp
            }
            panel?.orderOut(nil)
            backdropPanel?.orderOut(nil)
            floatingPanel?.orderFrontRegardless()
        }
    }

    /// 打开登录窗口。成功后立刻补齐云端数据：未读、云任务、额度，并补报攒下的活跃桶。
    private func presentLogin() {
        LoginWindowController.shared.present(refreshing: store)
    }

    /// 每次启动引导登录一次。
    /// 凭据只在内存里（不落盘、不碰钥匙串），启动时必然未登录 —— 不引导用户就只会看到一个未登录面板，
    /// 「本版本已引导过」这类标记已无意义。用户关掉后不再自动弹，之后靠面板提示与菜单项自救。
    private func offerLoginOnLaunch() {
        // 等面板先出现：启动瞬间弹窗既突兀，也会和首帧渲染抢主线程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            // 本次运行内已登录（刚登过）就不打扰
            guard AuthSession.shared.state != .ok else { return }
            self.presentLogin()
        }
    }

    /// 同 bundle id 的其他运行实例（排除自己）
    private static func otherRunningInstance() -> NSRunningApplication? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { $0.processIdentifier != me }
    }
}

extension Notification.Name {
    /// 跨进程：重复启动的新实例请已运行的实例把面板重新置前
    static let hudShowRequest = Notification.Name("com.wpscomate.hud.showRequest")
}
