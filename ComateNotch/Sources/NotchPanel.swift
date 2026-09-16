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
    let wingWidth: CGFloat = 48  // 从 68 缩小到 48，更紧凑
    /// 收起态总宽（动态）：必须 > 刘海宽，否则整个 HUD 被刘海盖住
    var collapsedWidth: CGFloat { (notch.notchRight - notch.notchLeft) + wingWidth * 2 }
    let expandedWidth: CGFloat = 320  // 从 340 缩小到 320
    let expandedHeight: CGFloat = 280  // 从 320 缩小到 280
    private let anchorTopY: CGFloat

    init() {
        let screen = NSScreen.screens.first ?? NSScreen.main!
        self.notch = NotchPanel.notchGeometry(for: screen)
        self.anchorTopY = screen.frame.maxY - notch.notchHeight

        // super.init 之前不能用 self 的计算属性，直接用已初始化的存储属性计算
        let collapsedW = (notch.notchRight - notch.notchLeft) + wingWidth * 2
        let frame = NSRect(x: notch.centerX - collapsedW / 2,
                           y: anchorTopY, width: collapsedW, height: notch.notchHeight)
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
        self.contentView?.wantsLayer = true
        // 窗口内容用 NotchShape 裁剪，收起态有圆角底部
        if let layer = self.contentView?.layer {
            let maskLayer = CAShapeLayer()
            let r: CGFloat = 14
            let w = collapsedW
            let h = notch.notchHeight
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: w, y: r))
            path.addArc(tangent1End: CGPoint(x: w, y: 0), tangent2End: CGPoint(x: w - r, y: 0), radius: r)
            path.addLine(to: CGPoint(x: r, y: 0))
            path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: 0, y: r), radius: r)
            path.closeSubpath()
            maskLayer.path = path
            maskLayer.fillColor = NSColor.white.cgColor
            layer.mask = maskLayer
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func expandedFrame() -> NSRect {
        let screen = NSScreen.screens.first ?? NSScreen.main!
        let expandedY = screen.frame.maxY - expandedHeight
        return NSRect(x: notch.centerX - expandedWidth / 2,
                      y: expandedY, width: expandedWidth, height: expandedHeight)
    }

    private func maskPath(w: CGFloat, h: CGFloat, cornerR: CGFloat) -> CGPath {
        let r = min(cornerR, w / 2, h / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w, y: h - r))
        path.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w - r, y: h), radius: r)
        path.addLine(to: CGPoint(x: r, y: 0))
        path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: 0, y: r), radius: r)
        path.closeSubpath()
        return path
    }

    func animateToCollapsed() {
        let target = NSRect(x: notch.centerX - collapsedWidth / 2,
                            y: anchorTopY, width: collapsedWidth, height: notch.notchHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
            // 同步动画 mask 到收起态圆角
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            if let layer = self.contentView?.layer,
               let currentMask = layer.mask as? CAShapeLayer {
                currentMask.path = maskPath(w: collapsedWidth, h: notch.notchHeight, cornerR: 14)
            }
            CATransaction.commit()
        }
    }

    func animateToExpanded() {
        let target = expandedFrame()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
            // 同步动画 mask 到展开态圆角
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            if let layer = self.contentView?.layer,
               let currentMask = layer.mask as? CAShapeLayer {
                currentMask.path = maskPath(w: expandedWidth, h: expandedHeight, cornerR: 16)
            }
            CATransaction.commit()
        }
    }
}
