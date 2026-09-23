import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var backdropPanel: NotchBackdropPanel?
    private var floatingPanel: FloatingPanel?
    private var store = ComateStore()
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
            onShowMainWindow: { [weak self] in
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            },
            onSwitchMode: { [weak self] mode in
                self?.switchDisplayMode(mode)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        // hostingView 固定为展开态尺寸并吸顶，不随窗口高度动画改变尺寸。
        // 否则 NSHostingView 每次窗口 resize 都要重排，且窗口变矮时内容会被
        // 推到底部（AppKit 默认底部锚定）→ 展开动画期间顶部 logo/状态灯/+ 跳动。
        // 窗口收起时超出部分由窗口自身裁剪，可见区域正好是内容顶部。
        let container = NSView(frame: NSRect(x: 0, y: 0,
                                             width: panel.expandedWidth,
                                             height: panel.hostingHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0,
                               width: panel.expandedWidth,
                               height: panel.hostingHeight)
        // minYMargin 弹性 = 顶部边距固定 → 视图始终吸在窗口顶部
        hosting.autoresizingMask = [NSView.AutoresizingMask.minYMargin]
        container.addSubview(hosting)
        panel.contentView = container
        store.start()
        // 应用上次保存的显示模式（否则启动后总是显示刘海面板）
        switchDisplayMode(store.displayMode)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let obs = screenObserver { NotificationCenter.default.removeObserver(obs) }
        store.stop()
    }

    private func switchDisplayMode(_ mode: ComateStore.DisplayMode) {
        store.displayMode = mode
        switch mode {
        case .notchHUD:
            // 切回刘海模式：隐藏浮动面板，显示刘海面板
            floatingPanel?.orderOut(nil)
            floatingPanel = nil
            panel?.orderFrontRegardless()
            backdropPanel?.orderFrontRegardless()
        case .floating:
            // 切到浮动模式：隐藏刘海面板，创建浮动面板
            panel?.orderOut(nil)
            backdropPanel?.orderOut(nil)
            let fp = FloatingPanel(store: store)
            self.floatingPanel = fp
            fp.orderFrontRegardless()
        }
    }
}
