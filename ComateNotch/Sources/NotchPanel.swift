import AppKit
import SwiftUI

/// 贴合 MacBook 刘海的悬浮 HUD 窗口。
/// 展开时顶部锚定不动，仅向下生长（消除 hover 跳动）。
/// 支持外接显示器热插拔：屏幕变化时自动重新定位到主屏幕。
final class NotchPanel: NSPanel {

    struct NotchGeometry {
        let centerX: CGFloat
        let notchLeft: CGFloat
        let notchRight: CGFloat
        let notchHeight: CGFloat
        let hasNotch: Bool
        /// 屏幕顶部 y（AppKit 坐标），收起态窗口的 y 即此值减刘海高
        let screenTopY: CGFloat
    }

    /// 取不到屏幕时的虚拟画布：只为让进程不崩，面板不可见
    private static let virtualScreen = NSRect(x: 0, y: 0, width: 1920, height: 1080)

    /// NSScreen.main 在无外接显示器 / 快速切换用户 / 登录窗口阶段可能为 nil，
    /// 所以入参可空，调用方不传时自行兜底。
    static func notchGeometry(for screen: NSScreen?) -> NotchGeometry {
        guard let screen = screen else {
            NSLog("[NotchPanel] 未取到任何屏幕，使用虚拟几何兜底")
            let frame = virtualScreen
            return NotchGeometry(centerX: frame.midX,
                                 notchLeft: frame.midX - 100,
                                 notchRight: frame.midX + 100,
                                 notchHeight: 34, hasNotch: false,
                                 screenTopY: frame.maxY)
        }
        if #available(macOS 12.0, *) {
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                return NotchGeometry(
                    centerX: (left.maxX + right.minX) / 2,
                    notchLeft: left.maxX, notchRight: right.minX,
                    notchHeight: max(screen.frame.maxY - right.minY, 34),
                    hasNotch: true,
                    screenTopY: screen.frame.maxY)
            }
        }
        return NotchGeometry(centerX: screen.frame.midX,
                             notchLeft: screen.frame.midX - 100,
                             notchRight: screen.frame.midX + 100,
                             notchHeight: 34, hasNotch: false,
                             screenTopY: screen.frame.maxY)
    }

    let notch: NotchGeometry
    /// 收起态左右翼宽度：刘海两侧可显示区域的宽度
    /// HUD 总宽 = 刘海宽 + 左翼 + 右翼，中间段被刘海硬件遮挡，纯黑融合
    let wingWidth: CGFloat = 36  // 收窄到 36
    /// HUD 宽度：收起态与展开态必须使用同一宽度。
    /// 否则 281(收起) vs 280(展开) 在动画中会让左边位移 0.5px、右边位移 1px，
    /// 表现为"展开/收起时右边没对齐"。同宽后动画只改变 y 与高度。
    var hudWidth: CGFloat { (notch.notchRight - notch.notchLeft) + wingWidth * 2 }
    /// 收起态总宽（动态）：必须 > 刘海宽，否则整个 HUD 被刘海盖住
    var collapsedWidth: CGFloat { hudWidth }
    /// 展开态宽度 = 收起态宽度（同宽，保证左右边缘在动画中完全不动）
    var expandedWidth: CGFloat { hudWidth }
    /// hostingView 的固定高度：远大于内容最大自然高度（10 条 ≈ 435pt），
    /// 为拖拽放大留足余量。展开态高度由内容自然高度决定（条数变化跟随），
    /// 但 hostingView 尺寸必须恒定，否则又会重新布局导致顶部跳动；窗口只负责裁剪可见区域。
    let hostingHeight: CGFloat = 720
    private let anchorTopY: CGFloat

    init() {
        // NSScreen.main 可能为 nil（无外接显示器 / 切用户），notchGeometry 内部兜底
        let screen = NSScreen.main ?? NSScreen.screens.first
        self.notch = NotchPanel.notchGeometry(for: screen)
        self.anchorTopY = notch.screenTopY - notch.notchHeight

        // super.init 之前不能用 self 的计算属性，直接用已初始化的存储属性计算
        // 窗口初始为收起态尺寸（宽度全程不变，见 hudWidth）
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

    /// 展开态窗口 frame：高度由内容实际高度决定（条数动态变化），顶部锚定屏幕顶
    func expandedFrame(height: CGFloat) -> NSRect {
        // 锚定窗口顶部：top = anchorTopY + notchHeight = screen.maxY
        let h = max(height, notch.notchHeight)
        let y = anchorTopY - (h - notch.notchHeight)
        return NSRect(x: notch.centerX - expandedWidth / 2,
                      y: y, width: expandedWidth, height: h)
    }

    /// 收起态窗口 frame（顶部锚定于屏幕顶），供静态托底窗口复用
    func collapsedFrame() -> NSRect {
        NSRect(x: notch.centerX - collapsedWidth / 2,
               y: anchorTopY, width: collapsedWidth, height: notch.notchHeight)
    }

    /// 拖拽调整高度时立即改窗口尺寸（不走动画，保证跟手）
    func setExpandedHeightImmediate(_ height: CGFloat) {
        setFrame(expandedFrame(height: height), display: true)
    }

    /// 拖拽开始：窗口先一次性撑到最大高度，拖拽过程中只动 SwiftUI 内容高度。
    /// 每次鼠标移动都 setFrame 会重新布局 hostingView，导致卡顿与抖动。
    func beginLiveResize(maxHeight: CGFloat) {
        setFrame(expandedFrame(height: maxHeight), display: true)
    }

    /// 外接显示器热插拔：屏幕数量/排列变化时重新定位到主屏幕
    func repositionToMainScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            NSLog("[NotchPanel] reposition: 无可用屏幕")
            return
        }
        let newNotch = NotchPanel.notchGeometry(for: screen)
        // 如果主屏幕没变（frame 完全一致），跳过无意义的重定位
        if newNotch.centerX == notch.centerX && newNotch.screenTopY == notch.screenTopY {
            NSLog("[NotchPanel] reposition: 主屏幕未变化，跳过")
            return
        }
        NSLog("[NotchPanel] reposition: 屏幕变化，从 (%.0f,%.0f) 移动到 (%.0f,%.0f)",
              notch.centerX, notch.screenTopY, newNotch.centerX, newNotch.screenTopY)
        // 由于 NotchGeometry 是 let 不可变，需要重建面板
        // 简单方案：直接移动窗口 frame 到新屏幕的对应位置
        let newX = newNotch.centerX - collapsedWidth / 2
        let newY = newNotch.screenTopY - notch.notchHeight
        let target = NSRect(x: newX, y: newY, width: collapsedWidth, height: notch.notchHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(target, display: true)
        }
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

    func animateToExpanded(height: CGFloat) {
        let target = expandedFrame(height: height)
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
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.ignoresMouseEvents = true
        self.titleVisibility = .hidden
        self.title = ""
        self.isReleasedWhenClosed = false

        // 用与主面板一致的 NotchShape（底部圆角）绘制黑色托底，
        // 纯矩形会在圆角处露出直角，形状一致才能与主面板无缝衔接
        let host = NSHostingView(rootView:
            NotchShape(cornerRadius: 14)
                .fill(Color.black)
                .frame(width: collapsedFrame.width, height: collapsedFrame.height)
        )
        host.frame = NSRect(origin: .zero, size: collapsedFrame.size)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
