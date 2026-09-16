import AppKit

/// 贴合 MacBook 刘海的悬浮 HUD 窗口。
/// 展开时顶部锚定不动，仅向下生长（消除 hover 跳动）。
final class NotchPanel: NSPanel {

    struct NotchGeometry {
        let centerX: CGFloat
        let notchLeft: CGFloat
        let notchRight: CGFloat
        let notchHeight: CGFloat
        let hasNotch: Bool
    }

    static func notchGeometry(for screen: NSScreen) -> NotchGeometry {
        if #available(macOS 12.0, *) {
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                return NotchGeometry(
                    centerX: (left.maxX + right.minX) / 2,
                    notchLeft: left.maxX, notchRight: right.minX,
                    notchHeight: max(screen.frame.maxY - right.minY, 34),
                    hasNotch: true)
            }
        }
        return NotchGeometry(centerX: screen.frame.midX,
                             notchLeft: screen.frame.midX - 100,
                             notchRight: screen.frame.midX + 100,
                             notchHeight: 34, hasNotch: false)
    }

    let notch: NotchGeometry
    let collapsedWidth: CGFloat = 80
    let expandedWidth: CGFloat = 340
    let expandedHeight: CGFloat = 320
    private let anchorTopY: CGFloat

    init() {
        let screen = NSScreen.screens.first ?? NSScreen.main!
        self.notch = NotchPanel.notchGeometry(for: screen)
        self.anchorTopY = screen.frame.maxY - notch.notchHeight

        let frame = NSRect(x: notch.centerX - collapsedWidth / 2,
                           y: anchorTopY, width: collapsedWidth, height: notch.notchHeight)
        let styleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView, .nonactivatingPanel]
        super.init(contentRect: frame, styleMask: styleMask, backing: .buffered, defer: false)
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.ignoresMouseEvents = false
        self.titleVisibility = .hidden
        self.title = ""
        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func expandedFrame() -> NSRect {
        NSRect(x: notch.centerX - expandedWidth / 2,
               y: anchorTopY, width: expandedWidth, height: expandedHeight)
    }

    func animateToCollapsed() {
        let target = NSRect(x: notch.centerX - collapsedWidth / 2,
                            y: anchorTopY, width: collapsedWidth, height: notch.notchHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
        }
    }

    func animateToExpanded() {
        let target = expandedFrame()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
        }
    }
}
