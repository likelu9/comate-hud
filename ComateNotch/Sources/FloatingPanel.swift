import AppKit
import SwiftUI

/// 任意悬浮模式：固定尺寸窗口（展开态大小），收起态通过遮罩只露出圆形图标。
/// 窗口 frame 永不改变 → 图标永不跳动。hover 切换遮罩实现展开/收起。
final class FloatingPanel: NSPanel {

    private let store: ComateStore
    private var isDragging = false
    private var dragOffset: CGPoint = .zero

    /// 收起态：圆形直径
    static let collapsedSize: CGFloat = 48
    /// 展开态宽度
    static let expandedWidth: CGFloat = 300
    /// 展开态高度
    static let expandedHeight: CGFloat = 360
    /// 图标距顶部的偏移
    static let iconTopOffset: CGFloat = 16

    init(store: ComateStore) {
        self.store = store

        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let cx = sf.minX + store.floatingPositionX * sf.width
        let cy = sf.minY + store.floatingPositionY * sf.height

        let w = Self.expandedWidth
        let h = Self.expandedHeight
        let iconCenterY = h - Self.iconTopOffset - Self.collapsedSize / 2
        let initialFrame = NSRect(x: cx - w / 2,
                                  y: cy - iconCenterY,
                                  width: w, height: h)

        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]

        super.init(contentRect: initialFrame, styleMask: styleMask, backing: .buffered, defer: false)
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
        self.contentView?.layer?.cornerRadius = 16
        self.contentView?.layer?.masksToBounds = true

        let contentView = FloatingPanelContent(store: store, panel: self)
        let hosting = NSHostingView(rootView: AnyView(contentView))
        hosting.frame = NSRect(x: 0, y: 0, width: w, height: h)
        self.contentView = hosting

        NSLog("[FloatingPanel] init: iconCenter=(%.0f,%.0f)", cx, cy)
    }

    // MARK: - 拖拽

    func beginDrag(at screenPoint: NSPoint) {
        isDragging = true
        dragOffset = NSPoint(x: screenPoint.x - frame.origin.x,
                             y: screenPoint.y - frame.origin.y)
    }

    func continueDrag(at screenPoint: NSPoint) {
        guard isDragging else { return }
        let newX = screenPoint.x - dragOffset.x
        let newY = screenPoint.y - dragOffset.y

        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let clampedX = max(sf.minX + 12, min(newX, sf.maxX - frame.width - 12))
        let clampedY = max(sf.minY + 12, min(newY, sf.maxY - frame.height - 12))

        setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }

    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let iconCenterX = frame.origin.x + Self.expandedWidth / 2
        let iconCenterY = frame.origin.y + Self.expandedHeight - Self.iconTopOffset - Self.collapsedSize / 2
        let normX = (iconCenterX - sf.minX) / sf.width
        let normY = (iconCenterY - sf.minY) / sf.height
        store.saveFloatingPosition(x: normX, y: normY)
    }

    // MARK: - 外接显示器适配

    func repositionToMainScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let cx = sf.minX + store.floatingPositionX * sf.width
        let cy = sf.minY + store.floatingPositionY * sf.height
        let iconCenterY = Self.expandedHeight - Self.iconTopOffset - Self.collapsedSize / 2
        let target = NSRect(x: cx - Self.expandedWidth / 2,
                            y: cy - iconCenterY,
                            width: Self.expandedWidth,
                            height: Self.expandedHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            self.animator().setFrame(target, display: true)
        }
    }
}

// MARK: - SwiftUI 内容

struct FloatingPanelContent: View {
    @ObservedObject var store: ComateStore
    let panel: FloatingPanel
    @State private var isHovering = false
    @State private var isDragging = false

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
            // 图标区域：固定在顶部
            ZStack {
                if isHovering {
                    Color.black.opacity(0.95)
                        .transition(.opacity)
                }
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .frame(width: 48, height: 48)
                    Circle()
                        .fill(lightColor)
                        .frame(width: 10, height: 10)
                        .offset(x: -2, y: -2)
                        .shadow(color: lightColor.opacity(0.6), radius: 4)
                }
                .frame(width: 48, height: 48)
                .opacity(store.primaryLight == .gray ? 0.4 : 1.0)
            }
            .frame(width: FloatingPanel.expandedWidth,
                   height: FloatingPanel.iconTopOffset + FloatingPanel.collapsedSize + 8)
            .onHover { hovering in
                guard !isDragging else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in
                        if !isDragging {
                            isDragging = true
                            let loc = NSEvent.mouseLocation
                            let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
                            let flipped = NSPoint(x: loc.x, y: screen.frame.height - loc.y)
                            panel.beginDrag(at: flipped)
                        }
                        let loc = NSEvent.mouseLocation
                        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
                        let flipped = NSPoint(x: loc.x, y: screen.frame.height - loc.y)
                        panel.continueDrag(at: flipped)
                    }
                    .onEnded { _ in
                        isDragging = false
                        panel.endDrag()
                    }
            )

            // 展开内容区域
            if isHovering {
                Divider().background(Color.white.opacity(0.15))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comate HUD")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    Text("展开态内容区")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onHover { hovering in
                    if !hovering {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = false
                        }
                    }
                }
            }
        }
        .frame(width: FloatingPanel.expandedWidth, height: FloatingPanel.expandedHeight)
    }
}
