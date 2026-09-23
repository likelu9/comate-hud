import AppKit
import Combine
import SwiftUI

/// 悬浮模式交互状态：由 AppKit 原生事件驱动，SwiftUI 订阅渲染。
final class FloatingInteraction: ObservableObject {
    @Published var isExpanded = false
}

/// 自定义内容视图：负责 hover 展开/收起、拖拽移动，并把透明区域的事件透传给下层窗口。
final class FloatingContentView: NSView {

    weak var panel: FloatingPanel?
    let interaction: FloatingInteraction

    /// 收起态可交互区域（图标圆），AppKit 坐标（原点左下）
    var collapsedHitRect: NSRect = .zero
    private var trackingArea: NSTrackingArea?

    private var isDragging = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero

    init(frame: NSRect, interaction: FloatingInteraction) {
        self.interaction = interaction
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 当前可交互区域：展开态为整个窗口，收起态仅图标圆
    private var activeHitRect: NSRect {
        interaction.isExpanded ? bounds : collapsedHitRect
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }

    /// 透明区域返回 nil → 点击穿透到下层窗口；可交互区域返回 self → 由本视图处理
    override func hitTest(_ point: NSPoint) -> NSView? {
        activeHitRect.contains(point) ? self : nil
    }

    // MARK: - Hover

    private func updateHover(at p: NSPoint) {
        let inside = activeHitRect.contains(p)
        if inside {
            if !interaction.isExpanded {
                interaction.isExpanded = true
                updateTrackingAreas()
            }
        } else if interaction.isExpanded && !isDragging {
            interaction.isExpanded = false
            updateTrackingAreas()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }
    override func mouseMoved(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }
    override func mouseExited(with event: NSEvent) {
        if interaction.isExpanded && !isDragging {
            interaction.isExpanded = false
            updateTrackingAreas()
        }
    }

    // MARK: - 拖拽（屏幕坐标增量，精确且跟手）

    override func mouseDown(with event: NSEvent) {
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - dragStartMouse.x
        let dy = cur.y - dragStartMouse.y
        if !isDragging && (abs(dx) > 2 || abs(dy) > 2) { isDragging = true }
        guard isDragging else { return }
        let target = NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy)
        win.setFrameOrigin(panel?.clampOrigin(target) ?? target)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            panel?.savePosition()
        }
        updateTrackingAreas()
    }
}

/// 任意悬浮模式：固定尺寸窗口，收起态只露出顶部圆形图标，hover 展开为矩形面板。
/// 窗口 frame 永不改变（仅拖拽时移动）→ 图标不会因展开而跳动。
final class FloatingPanel: NSPanel {

    private let store: ComateStore
    private let interaction = FloatingInteraction()

    static let collapsedSize: CGFloat = 48
    static let expandedWidth: CGFloat = 300
    static let iconTopOffset: CGFloat = 12
    static let expandedContentHeight: CGFloat = 320
    static var panelHeight: CGFloat { iconTopOffset + collapsedSize + expandedContentHeight }

    init(store: ComateStore) {
        self.store = store

        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let w = Self.expandedWidth
        let h = Self.panelHeight
        let iconCenterFromTop = Self.iconTopOffset + Self.collapsedSize / 2

        // 图标中心：优先还原持久化位置，否则默认屏幕中央
        let savedX = UserDefaults.standard.object(forKey: "notch.floatingPosX") as? CGFloat
        let savedY = UserDefaults.standard.object(forKey: "notch.floatingPosY") as? CGFloat
        let iconCenter: NSPoint
        if let sx = savedX, let sy = savedY {
            iconCenter = NSPoint(x: sf.minX + sx * sf.width, y: sf.minY + sy * sf.height)
        } else {
            iconCenter = NSPoint(x: sf.midX, y: sf.midY)
        }

        var origin = NSPoint(x: iconCenter.x - w / 2,
                             y: iconCenter.y - (h - iconCenterFromTop))
        // 初始化即钳制在屏幕内，避免出现在屏幕外
        origin.x = max(sf.minX + 4, min(origin.x, sf.maxX - w - 4))
        origin.y = max(sf.minY + 4, min(origin.y, sf.maxY - h - 4))
        let initialFrame = NSRect(x: origin.x, y: origin.y, width: w, height: h)

        super.init(contentRect: initialFrame,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)

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
        // 关键：允许接收 mouseMoved 事件，tracking area 才能工作
        self.acceptsMouseMovedEvents = true

        // 内容视图
        let content = FloatingContentView(frame: NSRect(x: 0, y: 0, width: w, height: h),
                                          interaction: interaction)
        content.panel = self
        let iconX = (w - Self.collapsedSize) / 2
        let iconY = h - Self.iconTopOffset - Self.collapsedSize
        content.collapsedHitRect = NSRect(x: iconX, y: iconY,
                                          width: Self.collapsedSize, height: Self.collapsedSize)

        let host = NSHostingView(rootView: AnyView(
            FloatingPanelContent(store: store, interaction: interaction)))
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        self.contentView = content

        NSLog("[FloatingPanel] frame=(%.0f,%.0f,%.0f,%.0f) iconRect=(%.0f,%.0f,%.0f,%.0f)",
              origin.x, origin.y, w, h, iconX, iconY, Self.collapsedSize, Self.collapsedSize)
    }

    /// 将窗口 origin 钳制在所属屏幕范围内
    func clampOrigin(_ p: NSPoint) -> NSPoint {
        let screen = self.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.frame
        let x = max(sf.minX + 4, min(p.x, sf.maxX - frame.width - 4))
        let y = max(sf.minY + 4, min(p.y, sf.maxY - frame.height - 4))
        return NSPoint(x: x, y: y)
    }

    /// 保存图标中心的归一化坐标
    func savePosition() {
        let screen = self.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.frame
        let iconCenterX = frame.origin.x + frame.width / 2
        let iconCenterY = frame.origin.y + frame.height - (Self.iconTopOffset + Self.collapsedSize / 2)
        store.saveFloatingPosition(x: (iconCenterX - sf.minX) / sf.width,
                                   y: (iconCenterY - sf.minY) / sf.height)
    }

    /// 外接显示器热插拔后重新定位到主屏幕
    func repositionToMainScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let iconCenter = NSPoint(x: sf.minX + store.floatingPositionX * sf.width,
                                 y: sf.minY + store.floatingPositionY * sf.height)
        let iconCenterFromTop = Self.iconTopOffset + Self.collapsedSize / 2
        var target = NSRect(x: iconCenter.x - frame.width / 2,
                            y: iconCenter.y - (frame.height - iconCenterFromTop),
                            width: frame.width, height: frame.height)
        target.origin = clampOrigin(target.origin)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            self.animator().setFrame(target, display: true)
        }
    }
}

// MARK: - SwiftUI 内容：收起态圆形图标 / 展开态面板

struct FloatingPanelContent: View {
    @ObservedObject var store: ComateStore
    @ObservedObject var interaction: FloatingInteraction

    private var lightColor: Color {
        switch store.primaryLight {
        case .yellow:  return .yellow
        case .red:     return .red
        case .green:   return .green
        case .gray:    return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 图标（收起态唯一可见元素，位置固定不动）
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: FloatingPanel.collapsedSize, height: FloatingPanel.collapsedSize)
                Circle()
                    .fill(lightColor)
                    .frame(width: 10, height: 10)
                    .offset(x: -2, y: -2)
                    .shadow(color: lightColor.opacity(0.6), radius: 4)
            }
            .frame(width: FloatingPanel.collapsedSize, height: FloatingPanel.collapsedSize)
            .opacity(store.primaryLight == .gray ? 0.45 : 1.0)
            .padding(.top, FloatingPanel.iconTopOffset)

            if interaction.isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)
        }
        .frame(width: FloatingPanel.expandedWidth,
               height: FloatingPanel.panelHeight,
               alignment: .top)
        .animation(.easeInOut(duration: 0.18), value: interaction.isExpanded)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comate HUD")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text("展开态内容区")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: FloatingPanel.expandedContentHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.top, 6)
    }
}
