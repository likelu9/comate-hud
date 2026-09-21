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
            onExpandChange: { [weak panel] isExpanded in
                if isExpanded { panel?.animateToExpanded() }
                else { panel?.animateToCollapsed() }
            },
            notchWidth: geo.notchRight - geo.notchLeft,
            wingWidth: panel.wingWidth,
            notchHeight: geo.notchHeight,
            expandedWidth: panel.expandedWidth,
            expandedHeight: panel.expandedHeight,
            onShowMainWindow: { [weak self] in
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting
        panel.orderFrontRegardless()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
