import AppKit
import SwiftUI

/// 任意悬浮模式：圆形窗口，logo 为主 + 状态灯辅助。
/// 常规态透明度弱化，hover 展开为矩形面板（与刘海模式交互一致）。
/// 支持鼠标拖拽自由移动，位置持久化。
final class FloatingPanel: NSPanel {

    private let store: ComateStore
    private let hostingView: NSHostingView<AnyView>
    private var isDragging = false
    private var dragOffset: CGPoint = .zero

    /// 收起态：圆形
    static let collapsedSize: CGFloat = 48
    /// 展开态宽度（与刘海模式保持一致的内容宽度）
    static let expandedWidth: CGFloat = 300
    /// 展开态最大高度
    static let expandedMaxHeight: CGFloat = 500

    init(store: ComateStore) {
        self.store = store

        // 初始位置：从持久化的归一化坐标还原
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let x = screenFrame.origin.x + store.floatingPositionX * screenFrame.width
        let y = screenFrame.origin.y + store.floatingPositionY * screenFrame.height
        let initialFrame = NSRect(x: x - Self.collapsedSize / 2,
                                  y: y - Self.collapsedSize / 2,
                                  width: Self.collapsedSize,
                                  height: Self.collapsedSize)

        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        self.hostingView = NSHostingView(rootView: AnyView(EmptyView()))

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

        // 裁剪为圆形
        self.contentView?.layer?.cornerRadius = Self.collapsedSize / 2
        self.contentView?.layer?.masksToBounds = true

        // 设置 SwiftUI 内容
        let contentView = FloatingPanelContent(store: store, panel: self)
        let hosting = NSHostingView(rootView: AnyView(contentView))
        hosting.frame = NSRect(x: 0, y: 0,
                               width: Self.collapsedSize,
                               height: Self.collapsedSize)
        self.contentView = hosting

        // 拖拽由 SwiftUI DragGesture 处理，无需全局监听

        NSLog("[FloatingPanel] init: pos=(%.0f,%.0f)", x, y)
    }

    // MARK: - 拖拽

    func beginDrag(at point: NSPoint) {
        isDragging = true
        dragOffset = NSPoint(x: point.x - frame.origin.x, y: point.y - frame.origin.y)
    }

    func continueDrag(at point: NSPoint) {
        guard isDragging else { return }
        let newX = point.x - dragOffset.x
        let newY = point.y - dragOffset.y

        // 限制在屏幕范围内
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let clampedX = max(sf.minX + 12, min(newX, sf.maxX - frame.width - 12))
        let clampedY = max(sf.minY + 12, min(newY, sf.maxY - frame.height - 12))

        setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }

    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        // 保存归一化位置
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let normX = (frame.midX - sf.minX) / sf.width
        let normY = (frame.midY - sf.minY) / sf.height
        store.saveFloatingPosition(x: normX, y: normY)
    }

    // MARK: - 展开/收起动画（锚定图标中心不动）

    func animateToExpanded(height: CGFloat) {
        let w = Self.expandedWidth
        let h = max(height, Self.collapsedSize)
        // 锚定当前图标中心点，向上扩展（图标中心 = 新 frame 底部中央）
        let centerX = frame.midX
        let iconBottom = frame.origin.y  // 当前图标底边
        let target = NSRect(x: centerX - w / 2,
                            y: iconBottom - (h - Self.collapsedSize),  // 向上扩展
                            width: w, height: h)

        self.contentView?.layer?.cornerRadius = 16

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
        }
    }

    func animateToCollapsed() {
        // 锚定当前窗口中心点，回到 48x48 圆形
        let cx = frame.midX
        let cy = frame.midY
        let target = NSRect(x: cx - Self.collapsedSize / 2,
                            y: cy - Self.collapsedSize / 2,
                            width: Self.collapsedSize,
                            height: Self.collapsedSize)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            self?.contentView?.layer?.cornerRadius = Self.collapsedSize / 2
            // 收起后保存位置（可能被展开撑偏了）
            if let s = self {
                let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
                let sf = screen.frame
                let normX = (s.frame.midX - sf.minX) / sf.width
                let normY = (s.frame.midY - sf.minY) / sf.height
                s.store.saveFloatingPosition(x: normX, y: normY)
            }
        }
    }

    func setFrameImmediate(height: CGFloat) {
        let w = Self.expandedWidth
        let h = max(height, Self.collapsedSize)
        let target = NSRect(x: frame.midX - w / 2,
                            y: frame.midY - h / 2,
                            width: w, height: h)
        setFrame(target, display: true)
    }

    // MARK: - 外接显示器适配

    func repositionToMainScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let x = sf.minX + store.floatingPositionX * sf.width
        let y = sf.minY + store.floatingPositionY * sf.height
        let target = NSRect(x: x - frame.width / 2,
                            y: y - frame.height / 2,
                            width: frame.width, height: frame.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            self.animator().setFrame(target, display: true)
        }
    }
}

// MARK: - SwiftUI 收起态内容：圆形 logo + 状态灯

struct FloatingPanelContent: View {
    @ObservedObject var store: ComateStore
    let panel: FloatingPanel
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var panelOrigin: CGPoint = .zero

    private var lightColor: Color {
        switch store.primaryLight {
        case .yellow:  return .yellow
        case .red:     return .red
        case .green:   return .green
        case .gray:    return .gray
        }
    }

    var body: some View {
        ZStack {
            if !isHovering {
                // 收起态：圆形 logo + 小状态灯
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
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStart = value.startLocation
                                panelOrigin = panel.frame.origin
                                panel.beginDrag(at: NSEvent.mouseLocation)
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            panel.endDrag()
                        }
                )
                .onHover { hovering in
                    guard !isDragging else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                    if hovering {
                        panel.animateToExpanded(height: 320)
                    }
                }
            } else {
                // 展开态：简化内容（后续可复用 NotchRootView）
                VStack(spacing: 8) {
                    HStack {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Comate HUD")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    Divider().background(Color.white.opacity(0.2))
                    Text("展开态内容")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .onHover { hovering in
                    if !hovering {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = false
                        }
                        panel.animateToCollapsed()
                    }
                }
            }
        }
    }
}
