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

        // 用户重复双击 App 时，由新实例发来置前请求；按当前模式重新置前面板即可
        // （switchDisplayMode 幂等，不会重建窗口）。观察者随进程存活，不需要移除
        _ = DistributedNotificationCenter.default().addObserver(
            forName: .hudShowRequest, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.switchDisplayMode(self.store.displayMode)
        }

        let panel = NotchPanel()
        self.panel = panel

        // 监听外接显示器热插拔：屏幕数量/排列变化时重新定位
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.panel?.repositionToMainScreen()
                self?.floatingPanel?.repositionToMainScreen()
            }
        }

        // 静态托底窗口：固定收起态尺寸，置于主面板下层，不参与动效
        let backdrop = NotchBackdropPanel(collapsedFrame: panel.collapsedFrame())
        self.backdropPanel = backdrop
        backdrop.orderFrontRegardless()

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
            onShowAbout: { AboutHUDWindow.show() })

        let view = NotchRootView(
            store: store,
            initialExpanded: CommandLine.arguments.contains("--expanded"),
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
        panel.contentView = container
        store.start()
        // 首次启动默认开启开机自启（仅一次，之后完全由菜单里的开关控制）
        LaunchAtLogin.applyDefaultOnFirstLaunch()
        // 应用上次保存的显示模式（否则启动后总是显示刘海面板）
        switchDisplayMode(store.displayMode)
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
                floatingPanel = fp
            }
            panel?.orderOut(nil)
            backdropPanel?.orderOut(nil)
            floatingPanel?.orderFrontRegardless()
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
