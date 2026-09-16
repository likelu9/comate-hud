import AppKit

/// 精确贴合 MacBook 刘海的悬浮 HUD 窗口。
/// 通过 auxiliaryTopLeftArea / auxiliaryTopRightArea 精确定位刘海中心。
/// 支持收起态（仅刘海高度）和展开态（向下展开）的帧动画。
final class NotchPanel: NSPanel {

    // MARK: - 刘海几何

    struct NotchGeometry {
        let centerX: CGFloat
        let notchLeft: CGFloat
        let notchRight: CGFloat
        let notchHeight: CGFloat
        let hasNotch: Bool
        var notchWidth: CGFloat { notchRight - notchLeft }
    }

    static func notchGeometry(for screen: NSScreen) -> NotchGeometry {
        if #available(macOS 12.0, *) {
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                let l = left.maxX
                let r = right.minX
                let h = screen.frame.maxY - right.minY
                return NotchGeometry(centerX: (l + r) / 2, notchLeft: l, notchRight: r,
                                     notchHeight: max(h, 34), hasNotch: true)
            }
        }
        return NotchGeometry(centerX: screen.frame.midX,
                             notchLeft: screen.frame.midX - 100,
                             notchRight: screen.frame.midX + 100,
                             notchHeight: 34, hasNotch: false)
    }

    // MARK: - 属性

    let notch: NotchGeometry
    let collapsedWidth: CGFloat = 280
    let expandedWidth: CGFloat = 340
    let expandedHeight: CGFloat = 320

    init() {
        let screen = NSScreen.screens.first ?? NSScreen.main!
        self.notch = NotchPanel.notchGeometry(for: screen)
        let frame = NotchPanel.collapsedFrame(notch: notch, screen: screen, width: collapsedWidth)
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

    // MARK: - 帧计算

    static func collapsedFrame(notch: NotchGeometry, screen: NSScreen, width: CGFloat) -> NSRect {
        NSRect(x: notch.centerX - width / 2,
               y: screen.frame.maxY - notch.notchHeight,
               width: width, height: notch.notchHeight)
    }

    func expandedFrame() -> NSRect {
        let screen = NSScreen.screens.first ?? NSScreen.main!
        return NSRect(x: notch.centerX - expandedWidth / 2,
                      y: screen.frame.maxY - expandedHeight,
                      width: expandedWidth, height: expandedHeight)
    }

    // MARK: - 动画

    func animateToCollapsed() {
        let screen = NSScreen.screens.first ?? NSScreen.main!
        let target = NotchPanel.collapsedFrame(notch: notch, screen: screen, width: collapsedWidth)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.30
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
        }
    }

    func animateToExpanded() {
        let target = expandedFrame()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.30
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
        }
    }
}
