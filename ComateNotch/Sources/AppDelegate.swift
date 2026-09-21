import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var backdropPanel: NotchBackdropPanel?
    private var store = ComateStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = NotchPanel()
        self.panel = panel

        // 静态托底窗口：固定收起态尺寸，置于主面板下层，不参与动效
        let backdrop = NotchBackdropPanel(collapsedFrame: panel.collapsedFrame())
        self.backdropPanel = backdrop
        backdrop.orderFrontRegardless()

        let geo = panel.notch
        let view = NotchRootView(
            store: store,
            initialExpanded: CommandLine.arguments.contains("--expanded"),
            onExpandChange: { [weak panel] isExpanded, height in
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
        hosting.autoresizingMask = [.minYMargin]
        container.addSubview(hosting)
        panel.contentView = container
        panel.orderFrontRegardless()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
