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
    /// 收起态左右翼宽度：刘海两侧可显示区域的宽度
    /// HUD 总宽 = 刘海宽 + 左翼 + 右翼，中间段被刘海硬件遮挡，纯黑融合
    let wingWidth: CGFloat = 36  // 收窄到 36
    /// 收起态总宽（动态）：必须 > 刘海宽，否则整个 HUD 被刘海盖住
    var collapsedWidth: CGFloat { (notch.notchRight - notch.notchLeft) + wingWidth * 2 }
    let expandedWidth: CGFloat = 280  // 收窄到 280
    let expandedHeight: CGFloat = 280  // 从 320 缩小到 280
    private let anchorTopY: CGFloat

    init() {
        let screen = NSScreen.main!
        self.notch = NotchPanel.notchGeometry(for: screen)
        self.anchorTopY = screen.frame.maxY - notch.notchHeight

        // super.init 之前不能用 self 的计算属性，直接用已初始化的存储属性计算
        // 窗口初始为收起态尺寸
        let collapsedW = (notch.notchRight - notch.notchLeft) + wingWidth * 2
        let frame = NSRect(x: notch.centerX - collapsedW / 2,
                           y: anchorTopY, width: collapsedW, height: notch.notchHeight)
        let styleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView, .nonactivatingPanel]
        super.init(contentRect: frame, styleMask: styleMask, backing: .buffered, defer: false)
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.level = NSWindow.Level(rawValue: 1000)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.ignoresMouseEvents = false
        self.titleVisibility = .hidden
        self.title = ""
        self.isReleasedWhenClosed = false
        self.contentView?.wantsLayer = true
        NSLog("[NotchPanel] window.frame=%@, isVisible=%d", NSStringFromRect(self.frame), self.isVisible)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func expandedFrame() -> NSRect {
        // 锚定窗口顶部：top = anchorTopY + notchHeight = screen.maxY
        // Y(底部) = screen.maxY - expandedHeight
        let y = anchorTopY - (expandedHeight - notch.notchHeight)
        return NSRect(x: notch.centerX - expandedWidth / 2,
                      y: y, width: expandedWidth, height: expandedHeight)
    }

    /// 收起态窗口 frame（顶部锚定于屏幕顶），供静态托底窗口复用
    func collapsedFrame() -> NSRect {
        NSRect(x: notch.centerX - collapsedWidth / 2,
               y: anchorTopY, width: collapsedWidth, height: notch.notchHeight)
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

/// 静态托底窗口：固定收起态尺寸、吸顶、不参与展开/收起动画。
/// 置于主面板下层，用于遮挡动效过程中露出的桌面背景（消除"不吸顶闪动"）。
/// 不接收鼠标事件，不影响主面板交互。
final class NotchBackdropPanel: NSPanel {
    init(collapsedFrame: NSRect) {
        super.init(contentRect: collapsedFrame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        // 低于主面板(1000)，保证主面板始终在上层
        self.level = NSWindow.Level(rawValue: 999)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isOpaque = true
        // 调试色：确认托底生效后改回 .black
        self.backgroundColor = NSColor.systemPink
        self.hasShadow = false
        self.isMovable = false
        self.ignoresMouseEvents = true
        self.titleVisibility = .hidden
        self.title = ""
        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
