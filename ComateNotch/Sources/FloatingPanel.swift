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

    /// 展开态面板区域（图标以下部分），AppKit 坐标（原点左下）
    private var expandedPanelRect: NSRect {
        let top = FloatingPanel.iconTopOffset + FloatingPanel.collapsedSize + FloatingPanel.iconPanelGap
        return NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - top))
    }

    /// 图标区 → 本视图处理（可拖拽）；展开态面板区 → 交给 SwiftUI（按钮、滚动可用）；
    /// 其余透明区 → nil，点击穿透到下层窗口
    override func hitTest(_ point: NSPoint) -> NSView? {
        if collapsedHitRect.contains(point) { return self }
        if interaction.isExpanded, expandedPanelRect.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }

    // MARK: - 右键菜单
    // 非激活 borderless 面板里 SwiftUI 的 contextMenu 不可靠，故用 AppKit 原生 NSMenu。
    // menu(for:) 覆盖整个窗口（AppKit 会沿 superview 向上找菜单）；
    // rightMouseDown 兼顾 hitTest 直接命中本视图（图标区）的情况。两者共用同一份菜单构建代码。

    override func menu(for event: NSEvent) -> NSMenu? {
        buildContextMenu()
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(buildContextMenu(), with: event, for: self)
    }

    private func buildContextMenu() -> NSMenu {
        guard let store = panel?.store else { return NSMenu() }
        let menu = NSMenu()

        let about = NSMenuItem(title: "关于 Comate HUD", action: #selector(menuAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let modeItem = NSMenuItem(title: "显示模式", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        for mode in ComateStore.DisplayMode.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(menuSwitchMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            if store.displayMode == mode { item.state = .on }
            modeMenu.addItem(item)
        }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        let mainItem = NSMenuItem(title: "显示主窗口", action: #selector(menuShowMain), keyEquivalent: "")
        mainItem.target = self
        menu.addItem(mainItem)
        menu.addItem(.separator())

        let limitItem = NSMenuItem(title: "最近记录条数", action: nil, keyEquivalent: "")
        let limitMenu = NSMenu()
        for n in ComateStore.recentTaskLimitOptions {
            let item = NSMenuItem(title: "最近 \(n) 条", action: #selector(menuSetLimit(_:)), keyEquivalent: "")
            item.target = self
            item.tag = n
            if store.recentTaskLimit == n { item.state = .on }
            limitMenu.addItem(item)
        }
        limitItem.submenu = limitMenu
        menu.addItem(limitItem)
        menu.addItem(.separator())

        if store.hasCustomExpandedHeight {
            let reset = NSMenuItem(title: "恢复默认高度", action: #selector(menuResetHeight), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)
            menu.addItem(.separator())
        }

        let quit = NSMenuItem(title: "退出悬浮窗", action: #selector(menuQuit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func menuAbout() { AboutHUDWindow.show() }

    @objc private func menuSwitchMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ComateStore.DisplayMode(rawValue: raw) else { return }
        panel?.onSwitchMode?(mode)
    }

    @objc private func menuShowMain() {
        panel?.store.openComateApp()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func menuSetLimit(_ sender: NSMenuItem) {
        panel?.store.recentTaskLimit = sender.tag
    }

    @objc private func menuResetHeight() { panel?.store.resetCustomExpandedHeight() }

    @objc private func menuQuit() {
        panel?.store.stop()
        NSApp.terminate(nil)
    }

    // MARK: - Hover（基于全局鼠标位置，不依赖 tracking area）

    /// 由全局/本地鼠标监听调用，用屏幕坐标判断是否进入图标或面板
    func evaluateHoverFromScreen() {
        guard let panel = panel else { return }
        if isDragging { return }

        let mouse = NSEvent.mouseLocation          // 屏幕坐标，原点左下
        let winFrame = panel.frame

        // 远离窗口时快速返回，并确保收起
        let near = winFrame.insetBy(dx: -80, dy: -80)
        if !near.contains(mouse) {
            if interaction.isExpanded { setExpanded(false) }
            return
        }

        // 图标中心（屏幕坐标）
        let iconCenter = NSPoint(
            x: winFrame.origin.x + winFrame.width / 2,
            y: winFrame.origin.y + winFrame.height
                - (FloatingPanel.iconTopOffset + FloatingPanel.collapsedSize / 2)
        )
        let radius = FloatingPanel.collapsedSize / 2 + 8
        let inIcon = hypot(mouse.x - iconCenter.x, mouse.y - iconCenter.y) <= radius
        // 展开态：整个面板矩形（顶部留 4pt 容差）
        let inPanel = winFrame.insetBy(dx: -4, dy: -4).contains(mouse)

        let inside = interaction.isExpanded ? inPanel : inIcon
        if inside != interaction.isExpanded {
            setExpanded(inside)
        }
    }

    private func setExpanded(_ expanded: Bool) {
        guard interaction.isExpanded != expanded else { return }
        interaction.isExpanded = expanded
        NSLog("[FloatingPanel] %@", expanded ? "expanded" : "collapsed")
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
    }
}

/// 任意悬浮模式：固定尺寸窗口，收起态只露出顶部圆形图标，hover 展开为矩形面板。
/// 窗口 frame 永不改变（仅拖拽时移动）→ 图标不会因展开而跳动。
final class FloatingPanel: NSPanel {

    let store: ComateStore
    /// 切换显示模式（由 AppDelegate 注入）
    var onSwitchMode: ((ComateStore.DisplayMode) -> Void)?
    private let interaction = FloatingInteraction()
    private var floatContent: FloatingContentView?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    static let collapsedSize: CGFloat = 48
    static let expandedWidth: CGFloat = 300
    static let iconTopOffset: CGFloat = 12
    /// 图标与展开面板之间的间距
    static let iconPanelGap: CGFloat = 6
    static let expandedContentHeight: CGFloat = 334
    static var panelHeight: CGFloat {
        iconTopOffset + collapsedSize + iconPanelGap + expandedContentHeight
    }

    init(store: ComateStore, onSwitchMode: ((ComateStore.DisplayMode) -> Void)? = nil) {
        self.store = store
        self.onSwitchMode = onSwitchMode

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
        self.floatContent = content

        // 鼠标监听：全局（鼠标在别的 App 上）+ 本地（鼠标在本窗口上）
        // 非激活 borderless 面板的 tracking area 不可靠，故用监听兜底
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.floatContent?.evaluateHoverFromScreen()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.floatContent?.evaluateHoverFromScreen()
            return event
        }

        NSLog("[FloatingPanel] frame=(%.0f,%.0f,%.0f,%.0f)", origin.x, origin.y, w, h)
    }

    deinit {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m) }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Comate HUD")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
                // 新建任务：仅在展开态出现
                ComatePlusButton { store.openNewTask() }
            }

            if store.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    HUDTaskRows(store: store, spacing: 3)
                }
                .frame(maxHeight: .infinity)
            }

            HUDUsageFooter(store: store)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: FloatingPanel.expandedContentHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.top, FloatingPanel.iconPanelGap)
    }
}
