import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var store = ComateStore()
    private var expanded: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel()
        self.panel = panel

        let binding = Binding<Bool>(
            get: { [weak self] in self?.expanded ?? false },
            set: { [weak self] val in self?.expanded = val }
        )

        let view = NotchRootView(store: store, expanded: binding) { [weak panel] isExpanded in
            if isExpanded {
                panel?.animateToExpanded()
            } else {
                panel?.animateToCollapsed()
            }
        }
        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting
        panel.orderFrontRegardless()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
