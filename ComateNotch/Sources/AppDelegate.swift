import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var store = ComateStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，做成纯刘海 HUD（可按需保留）
        // NSApp.setActivationPolicy(.accessory)

        let panel = NotchPanel()
        self.panel = panel

        let view = NotchRootView(store: store)
        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting
        panel.orderFrontRegardless()

        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
