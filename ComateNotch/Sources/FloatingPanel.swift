import AppKit
import Combine
import SwiftUI

// MARK: - 悬浮模式几何常量

enum FloatingMetrics {
    /// 图标交互区边长（比图形大一圈，便于抓取与 hover）
    static let iconBox: CGFloat = 44
    /// 图标图形边长（Comate logo，与刘海模式同一套矢量）
    static let logoSize: CGFloat = 30
    /// 状态灯直径（按刘海模式 18pt logo / 6pt 灯 的比例放大）
    static let lightSize: CGFloat = 10
    /// 状态灯光晕强度：图标比刘海模式大 1.67 倍，光晕按比例放大会发散，故收敛到 0.45
    static let lightGlow: CGFloat = 0.45
    /// 窗口内边距：留给状态灯发光，避免被窗口边缘裁掉
    static let pad: CGFloat = 8
    /// 图标与展开面板之间的间距
    static let gap: CGFloat = 6
    /// 面板圆角
    static let corner: CGFloat = 16
    /// 面板底部拖拽手柄高度
    static let handleHeight: CGFloat = 14
    /// 面板与屏幕边缘的最小距离
    static let screenMargin: CGFloat = 4
    /// 以下内边距 / 间距与刘海模式保持一致
    static let panelHPadding: CGFloat = 12
    static let panelTopPadding: CGFloat = 8
    static let panelBottomPadding: CGFloat = 6
    static let listSpacing: CGFloat = 3
    static let blockSpacing: CGFloat = 6
    /// 标题行高度（悬浮模式特有：标题 + 新建任务按钮）
    static let headerHeight: CGFloat = 18
}

/// 悬浮面板布局（SwiftUI 坐标，原点左上，相对窗口）
struct FloatingLayout: Equatable {
    var windowSize: CGSize = .zero
    var iconRect: CGRect = .zero
    var panelRect: CGRect = .zero
    /// 面板翻到了图标上方
    var panelAbove: Bool = false
    /// 展开动画锚点：面板上贴着图标的那条边
    var anchor: UnitPoint = .top
    var expanded: Bool = false
}

/// SwiftUI 实测的内容尺寸（回传给面板用于算窗口大小）
struct FloatingContentMetrics {
    /// 当前条数下的自然高度
    var natural: CGFloat
    /// 1 条记录的高度（最小高度）
    var minHeight: CGFloat
    /// 10 条记录的高度（最大高度）
    var maxHeight: CGFloat
}

/// 悬浮模式交互状态：由 AppKit 原生事件驱动，SwiftUI 订阅渲染。
final class FloatingInteraction: ObservableObject {
    @Published var isExpanded = false
    @Published var layout = FloatingLayout()

    /// SwiftUI 实测内容尺寸回传。不参与渲染，故不 @Published（避免刷新循环）
    var onContentMetrics: ((FloatingContentMetrics) -> Void)?
    /// 拖拽底部手柄调整高度：开始 / 结束
    var onResizeBegin: (() -> Void)?
    var onResizeEnd: (() -> Void)?
    /// 点击面板右下角设置按钮：弹出与右键一致的菜单
    var onShowMenu: (() -> Void)?
}

/// 自定义内容视图：负责 hover 展开/收起、拖拽移动，并把透明区域的事件透传给下层窗口。
final class FloatingContentView: NSView {

    weak var panel: FloatingPanel?
    let interaction: FloatingInteraction

    /// 图标交互区（窗口坐标，原点左下）：唯一可拖拽区域
    var iconHitRect: NSRect = .zero
    /// 展开态面板区（窗口坐标，原点左下）
    var panelHitRect: NSRect = .zero

    private var isDragging = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartIconCenter: NSPoint = .zero

    init(frame: NSRect, interaction: FloatingInteraction) {
        self.interaction = interaction
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// 图标区 → 本视图处理（可拖拽）；展开态面板区 → 交给 SwiftUI（按钮、滚动、拖高度可用）；
    /// 其余透明区 → nil，点击穿透到下层窗口
    override func hitTest(_ point: NSPoint) -> NSView? {
        if iconHitRect.contains(point) { return self }
        if interaction.isExpanded, panelHitRect.contains(point) {
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

    /// 面板右下角设置按钮：等同右键。
    /// 左键事件直接交给 popUpContextMenu 在非激活面板里不可靠，故合成一个右键按下事件，
    /// 走与右键完全相同的弹出手径（该路径已验证可用），定位到当前鼠标处。
    func showContextMenu() {
        let menu = buildContextMenu()
        let win = window
        let loc = win?.convertPoint(fromScreen: NSEvent.mouseLocation) ?? .zero
        if let ev = NSEvent.mouseEvent(with: .rightMouseDown, location: loc,
                                       modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                       windowNumber: win?.windowNumber ?? 0, context: nil,
                                       eventNumber: 0, clickCount: 1, pressure: 1) {
            NSMenu.popUpContextMenu(menu, with: ev, for: self)
            return
        }
        menu.popUp(positioning: nil, at: convert(loc, from: nil), in: self)
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

        let quit = NSMenuItem(title: "退出 Comate HUD", action: #selector(menuQuit), keyEquivalent: "")
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
        let iconRect = panel.iconRectScreen

        if interaction.isExpanded {
            // 展开态：面板与图标都算「里面」（两者之间有 gap，各留 4pt 容差正好接上）
            let inside = panel.panelRectScreen.insetBy(dx: -4, dy: -4).contains(mouse)
                || iconRect.insetBy(dx: -4, dy: -4).contains(mouse)
            if !inside { panel.setExpanded(false) }
        } else {
            // 收起态：仅图标区，留 4pt 容差
            if iconRect.insetBy(dx: -4, dy: -4).contains(mouse) {
                panel.setExpanded(true)
            }
        }
    }

    // MARK: - 拖拽（屏幕坐标增量，精确且跟手）

    override func mouseDown(with event: NSEvent) {
        // 仅图标区可拖拽窗口；面板区的按下（点任务、拖高度手柄）交给 SwiftUI
        let p = convert(event.locationInWindow, from: nil)
        guard iconHitRect.contains(p), let panel = panel else { return }
        dragStartMouse = NSEvent.mouseLocation
        dragStartIconCenter = panel.iconCenter
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let panel = panel else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - dragStartMouse.x
        let dy = cur.y - dragStartMouse.y
        if !isDragging && (abs(dx) > 2 || abs(dy) > 2) {
            isDragging = true
            // 拖拽期间收起列表，避免面板跟着手指乱跑
            panel.setExpanded(false)
        }
        guard isDragging else { return }
        panel.moveIconCenter(to: NSPoint(x: dragStartIconCenter.x + dx,
                                        y: dragStartIconCenter.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        panel?.endDrag()
    }
}

/// 任意悬浮模式：窗口始终以图标为锚点（窗口左上角随图标走），
/// 展开时窗口瞬时长大为「图标 ∪ 面板」的外接矩形，内容再从小图标下边缘动画展开
/// —— 图标位置全程不动，不会因展开而跳动。
final class FloatingPanel: NSPanel {

    let store: ComateStore
    /// 切换显示模式（由 AppDelegate 注入）
    var onSwitchMode: ((ComateStore.DisplayMode) -> Void)?
    /// 展开态宽度：与刘海模式保持一致
    let expandedWidth: CGFloat

    private let interaction = FloatingInteraction()
    private var floatContent: FloatingContentView?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    /// 图标中心（屏幕坐标，原点左下）
    private(set) var iconCenter: NSPoint
    /// 最近一次算出的面板矩形（屏幕坐标），供 hover 判定使用
    private(set) var panelRectScreen: NSRect = .zero

    /// 面板自然高度（实测）/ 最小（1 条）/ 最大（10 条）
    private var contentHeight: CGFloat = 300
    private var minContentHeight: CGFloat = 120
    private var maxContentHeight: CGFloat = 420
    /// 拖拽高度期间窗口先撑到最大高度，之后只改 SwiftUI 内容高度
    private var isLiveResizing = false
    /// 收起动画期间延迟缩窗，避免动画被窗口裁断
    private var collapseWorkItem: DispatchWorkItem?

    init(store: ComateStore,
         expandedWidth: CGFloat,
         onSwitchMode: ((ComateStore.DisplayMode) -> Void)? = nil) {
        self.store = store
        self.expandedWidth = expandedWidth
        self.onSwitchMode = onSwitchMode

        // 图标中心：优先还原持久化位置，否则默认屏幕中央
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
        let sf = screen.frame
        let savedX = UserDefaults.standard.object(forKey: "notch.floatingPosX") as? CGFloat
        let savedY = UserDefaults.standard.object(forKey: "notch.floatingPosY") as? CGFloat
        if let sx = savedX, let sy = savedY {
            iconCenter = NSPoint(x: sf.minX + sx * sf.width, y: sf.minY + sy * sf.height)
        } else {
            iconCenter = NSPoint(x: sf.midX, y: sf.midY)
        }

        // 初始为收起态：窗口就是图标盒子 + 内边距
        let side = FloatingMetrics.iconBox + FloatingMetrics.pad * 2
        let initialFrame = NSRect(x: iconCenter.x - side / 2,
                                  y: iconCenter.y - side / 2,
                                  width: side, height: side)

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
        let content = FloatingContentView(frame: NSRect(origin: .zero, size: initialFrame.size),
                                          interaction: interaction)
        content.panel = self
        let host = NSHostingView(rootView: AnyView(
            FloatingPanelContent(store: store, interaction: interaction)))
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        self.contentView = content
        self.floatContent = content

        // SwiftUI 实测内容尺寸 → 回填窗口大小
        interaction.onContentMetrics = { [weak self] m in
            guard let self = self else { return }
            let changed = abs(m.natural - self.contentHeight) > 0.5
                || abs(m.minHeight - self.minContentHeight) > 0.5
                || abs(m.maxHeight - self.maxContentHeight) > 0.5
            self.contentHeight = m.natural
            self.minContentHeight = m.minHeight
            self.maxContentHeight = m.maxHeight
            guard changed else { return }
            // 下一帧再改窗口：onPreferenceChange 回调里直接改会打断当前布局
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.applyLayout(expanded: self.interaction.isExpanded)
            }
        }
        interaction.onResizeBegin = { [weak self] in self?.beginLiveResize() }
        interaction.onResizeEnd = { [weak self] in self?.endLiveResize() }
        interaction.onShowMenu = { [weak self] in self?.floatContent?.showContextMenu() }

        // 用户拖拽底部手柄 / 右键「恢复默认高度」→ 面板高度变化
        store.$customExpandedHeight
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.interaction.isExpanded else { return }
                self.applyLayout(expanded: true)
            }
            .store(in: &cancellables)

        // 鼠标监听：全局（鼠标在别的 App 上）+ 本地（鼠标在本窗口上）
        // 非激活 borderless 面板的 tracking area 不可靠，故用监听兜底
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.floatContent?.evaluateHoverFromScreen()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.floatContent?.evaluateHoverFromScreen()
            return event
        }

        applyLayout(expanded: false)
    }

    deinit {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - 几何

    /// 图标交互区（屏幕坐标）
    var iconRectScreen: NSRect {
        NSRect(x: iconCenter.x - FloatingMetrics.iconBox / 2,
               y: iconCenter.y - FloatingMetrics.iconBox / 2,
               width: FloatingMetrics.iconBox, height: FloatingMetrics.iconBox)
    }

    /// 当前图标所在屏幕
    private func currentScreen() -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(iconCenter) }
            ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
    }

    /// 目标内容高度：自定义高度被夹在 [1 条, 10 条] 之间；未自定义时跟随内容
    private var targetContentHeight: CGFloat {
        let custom = store.customExpandedHeight ?? contentHeight
        return min(max(custom, minContentHeight), maxContentHeight)
    }

    /// 展开态面板矩形（屏幕坐标）。
    /// 垂直：优先放在图标下方，下方不够且上方更宽裕时翻到上方；
    /// 水平：默认左对齐图标（面板落在图标右下角），再夹到屏幕内。
    private func layoutGeometry(expanded: Bool) -> (win: NSRect, panel: NSRect, panelAbove: Bool) {
        let icon = iconRectScreen
        let sf = currentScreen().frame
        let m = FloatingMetrics.screenMargin
        let gap = FloatingMetrics.gap
        let h = targetContentHeight
        // 拖拽高度期间窗口按最大高度撑开，避免每次鼠标移动都改窗口
        let windowH = isLiveResizing ? maxContentHeight : h

        let spaceBelow = icon.minY - sf.minY - m
        let spaceAbove = sf.maxY - icon.maxY - m
        let below = spaceBelow >= windowH + gap || spaceBelow >= spaceAbove

        let w = expandedWidth
        let x = min(max(icon.minX, sf.minX + m), max(sf.minX + m, sf.maxX - w - m))
        // 面板与窗口共用同一条贴着图标的边，高度变化时顶部不动
        let top = below ? icon.minY - gap : icon.maxY + gap

        let panel = NSRect(x: x, y: below ? top - h : top, width: w, height: h)
        // 收起态窗口只有图标大小：面板不参与外接矩形，避免大块透明窗口盖住桌面
        var win = icon
        if expanded {
            let winPanel = NSRect(x: x, y: below ? top - windowH : top, width: w, height: windowH)
            win = icon.union(winPanel)
        }
        win = win.insetBy(dx: -FloatingMetrics.pad, dy: -FloatingMetrics.pad)
        return (win, panel, !below)
    }

    /// 重建布局并同步窗口尺寸。
    /// 收起态窗口只有图标大小，展开时窗口瞬时长大（全透明不可见），
    /// SwiftUI 内容再从小图标下边缘动画展开 —— 图标全程不动。
    private func applyLayout(expanded: Bool) {
        let g = layoutGeometry(expanded: expanded)
        if !isLiveResizing {
            setFrame(g.win, display: true)
        }
        panelRectScreen = g.panel

        var layout = FloatingLayout()
        layout.windowSize = g.win.size
        layout.iconRect = local(iconRectScreen, in: g.win)
        layout.panelRect = local(g.panel, in: g.win)
        layout.panelAbove = g.panelAbove
        layout.expanded = expanded
        // 展开动画锚点：面板上贴着图标的那条边（水平对到图标中心）
        layout.anchor = UnitPoint(
            x: g.panel.width > 0
                ? min(max((iconRectScreen.midX - g.panel.minX) / g.panel.width, 0), 1)
                : 0.5,
            y: g.panelAbove ? 1 : 0)
        interaction.layout = layout

        // 命中区域（窗口坐标，原点左下）
        floatContent?.iconHitRect = NSRect(x: iconRectScreen.minX - g.win.minX,
                                           y: iconRectScreen.minY - g.win.minY,
                                           width: FloatingMetrics.iconBox,
                                           height: FloatingMetrics.iconBox)
        floatContent?.panelHitRect = NSRect(x: g.panel.minX - g.win.minX,
                                            y: g.panel.minY - g.win.minY,
                                            width: g.panel.width, height: g.panel.height)
    }

    /// AppKit 屏幕矩形 → SwiftUI 局部矩形（原点左上）
    private func local(_ r: NSRect, in win: NSRect) -> CGRect {
        CGRect(x: r.minX - win.minX,
               y: win.maxY - r.maxY,
               width: r.width, height: r.height)
    }

    // MARK: - 展开 / 收起

    func setExpanded(_ expanded: Bool) {
        guard interaction.isExpanded != expanded else { return }
        collapseWorkItem?.cancel()
        if expanded {
            interaction.isExpanded = true
            applyLayout(expanded: true)
        } else {
            interaction.isExpanded = false
            // 内容淡出后再把窗口收回图标大小，否则收起动画会被窗口裁断
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.interaction.isExpanded else { return }
                // 延迟收起期间鼠标可能已回到图标/面板上，执行前重新校验，避免误收
                let mouse = NSEvent.mouseLocation
                let inside = self.panelRectScreen.insetBy(dx: -4, dy: -4).contains(mouse)
                    || self.iconRectScreen.insetBy(dx: -4, dy: -4).contains(mouse)
                if inside { return }
                self.applyLayout(expanded: false)
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: item)
        }
    }

    // MARK: - 拖拽移动

    /// 拖拽图标：钳制在「所有屏幕的并集」内 —— 允许跨屏拖，但图标不会跑出屏幕
    func moveIconCenter(to p: NSPoint) {
        iconCenter = clampIconCenter(p)
        applyLayout(expanded: interaction.isExpanded)
    }

    func endDrag() {
        savePosition()
        applyLayout(expanded: interaction.isExpanded)
    }

    private func clampIconCenter(_ p: NSPoint) -> NSPoint {
        var bounds = NSRect.null
        for s in NSScreen.screens { bounds = bounds.union(s.frame) }
        if bounds.isNull { bounds = currentScreen().frame }
        let half = FloatingMetrics.iconBox / 2
        return NSPoint(x: min(max(p.x, bounds.minX + half), bounds.maxX - half),
                       y: min(max(p.y, bounds.minY + half), bounds.maxY - half))
    }

    // MARK: - 拖拽调整高度

    private func beginLiveResize() {
        isLiveResizing = true
        applyLayout(expanded: true)
    }

    private func endLiveResize() {
        isLiveResizing = false
        applyLayout(expanded: interaction.isExpanded)
    }

    /// 保存图标中心的归一化坐标
    func savePosition() {
        let sf = currentScreen().frame
        store.saveFloatingPosition(x: (iconCenter.x - sf.minX) / sf.width,
                                   y: (iconCenter.y - sf.minY) / sf.height)
    }

    /// 外接显示器热插拔后重新定位。图标仍在某块屏上就不动（支持拖到副屏），
    /// 跑到屏幕外才拉回主屏。
    func repositionToMainScreen() {
        let stillVisible = NSScreen.screens.contains { $0.frame.intersects(iconRectScreen) }
        if !stillVisible {
            let sf = (NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]).frame
            iconCenter = clampIconCenter(NSPoint(x: sf.minX + store.floatingPositionX * sf.width,
                                                 y: sf.minY + store.floatingPositionY * sf.height))
        }
        applyLayout(expanded: interaction.isExpanded)
    }
}

// MARK: - SwiftUI 内容：图标（Comate logo + 状态灯）/ 展开态面板

struct FloatingPanelContent: View {
    @ObservedObject var store: ComateStore
    @ObservedObject var interaction: FloatingInteraction

    /// 实测：列表行 VStack 自然高度 + 该测量对应的行数
    @State private var rowsHeight: CGFloat = 0
    @State private var measuredRowCount: Int = 0
    /// 实测：页脚高度
    @State private var footerHeight: CGFloat = 0
    /// 拖拽高度手柄状态
    @State private var isResizing = false
    @State private var resizeHovered = false
    @State private var dragBaseHeight: CGFloat = 0

    private var layout: FloatingLayout { interaction.layout }

    private var displayedRowCount: Int { min(store.recentTaskLimit, store.recentTasks.count) }

    /// 单行占高（行高 + 行间距），由实测反推；与当前展示条数无关
    private var rowUnit: CGFloat {
        guard measuredRowCount > 0, rowsHeight > 0 else { return 0 }
        return (rowsHeight + FloatingMetrics.listSpacing) / CGFloat(measuredRowCount)
    }

    /// 指定条数时面板应有的高度（与刘海模式同一套算法，多一个标题行）
    private func contentHeight(forRows rows: Int) -> CGFloat {
        guard rowUnit > 0, footerHeight > 0 else { return 300 }
        let n = CGFloat(max(rows, 1))
        return FloatingMetrics.panelTopPadding
            + FloatingMetrics.headerHeight + FloatingMetrics.blockSpacing
            + rowUnit * n - FloatingMetrics.listSpacing
            + FloatingMetrics.blockSpacing + footerHeight
            + FloatingMetrics.panelBottomPadding
    }

    /// 列表可视高度：装得下就贴合内容，装不下则裁剪并可滚动
    private var listViewportHeight: CGFloat {
        guard footerHeight > 0 else { return rowsHeight }
        let avail = layout.panelRect.height
            - FloatingMetrics.panelTopPadding
            - FloatingMetrics.headerHeight - FloatingMetrics.blockSpacing
            - FloatingMetrics.blockSpacing
            - footerHeight
            - FloatingMetrics.panelBottomPadding
        return max(min(rowsHeight, avail), 0)
    }

    private func reportMetrics() {
        guard rowUnit > 0, footerHeight > 0 else { return }
        interaction.onContentMetrics?(FloatingContentMetrics(
            natural: contentHeight(forRows: displayedRowCount),
            minHeight: contentHeight(forRows: 1),
            maxHeight: contentHeight(forRows: ComateStore.recentTaskLimitOptions.max() ?? 10)))
    }

    private func updateRowsHeight(_ h: CGFloat) {
        guard h > 0, abs(h - rowsHeight) > 0.5 else { return }
        rowsHeight = h
        measuredRowCount = displayedRowCount
        reportMetrics()
    }

    private func updateFooterHeight(_ h: CGFloat) {
        guard h > 0, abs(h - footerHeight) > 0.5 else { return }
        footerHeight = h
        reportMetrics()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 图标：与刘海模式同一套视觉（Comate logo + 紧贴右下的状态灯），
            // 由 layout 绝对定位 → 展开/收起全程不动
            HUDLogoBadge(store: store,
                         logoSize: FloatingMetrics.logoSize,
                         lightSize: FloatingMetrics.lightSize,
                         glow: FloatingMetrics.lightGlow,
                         colorful: true)
                .frame(width: FloatingMetrics.iconBox, height: FloatingMetrics.iconBox)
                .position(x: layout.iconRect.midX, y: layout.iconRect.midY)

            // 面板：始终参与布局，靠 scale + opacity 做展开/收起。
            // 锚点贴在图标那条边上 → 看起来是从小图标下边缘展开的。
            // 收起态 panelRect 落在窗口外，会被窗口直接裁掉。
            panel
                .frame(width: layout.panelRect.width, height: layout.panelRect.height)
                .scaleEffect(interaction.isExpanded ? 1 : 0.94, anchor: layout.anchor)
                .opacity(interaction.isExpanded ? 1 : 0)
                .position(x: layout.panelRect.midX, y: layout.panelRect.midY)
                .allowsHitTesting(interaction.isExpanded)
        }
        .frame(width: layout.windowSize.width,
               height: layout.windowSize.height,
               alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: interaction.isExpanded)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: FloatingMetrics.blockSpacing) {
            // 标题行：标题 + 新建任务
            HStack(spacing: 6) {
                Text("Comate HUD")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
                ComatePlusButton { store.openNewTask() }
            }
            .frame(height: FloatingMetrics.headerHeight)

            if store.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    HUDTaskRows(store: store, spacing: FloatingMetrics.listSpacing)
                        .background(
                            GeometryReader { g in
                                Color.clear
                                    .onAppear { updateRowsHeight(g.size.height) }
                                    .onChange(of: g.size.height) { h in updateRowsHeight(h) }
                            }
                        )
                }
                .frame(height: listViewportHeight)
            }

            // 页脚吸底：面板被拖高时，额度/消息行贴在面板底部
            Spacer(minLength: 0)

            HUDUsageFooter(store: store, onSettings: { interaction.onShowMenu?() })
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { updateFooterHeight(g.size.height) }
                            .onChange(of: g.size.height) { h in updateFooterHeight(h) }
                    }
                )
        }
        .padding(.horizontal, FloatingMetrics.panelHPadding)
        .padding(.top, FloatingMetrics.panelTopPadding)
        .padding(.bottom, FloatingMetrics.panelBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: FloatingMetrics.corner)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FloatingMetrics.corner)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .bottom) { resizeHandle }
    }

    /// 底部拖拽手柄：向下拖变高（顶部锚定不动），与刘海模式交互一致
    private var resizeHandle: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            Capsule()
                .fill(Color.white.opacity(resizeHovered || isResizing ? 0.5 : 0.22))
                .frame(width: 44, height: 3)
                .padding(.bottom, 2)
        }
        .frame(height: FloatingMetrics.handleHeight)
        .onHover { h in
            guard h != resizeHovered else { return }
            resizeHovered = h
            if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
        }
        .gesture(resizeGesture)
    }

    /// 必须用 .global 坐标空间：手柄本身会跟着面板底边移动，
    /// 用 .local 时 translation 会被手柄自身位移抵消，表现为底边追不上鼠标。
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { v in
                if !isResizing {
                    isResizing = true
                    dragBaseHeight = layout.panelRect.height
                    interaction.onResizeBegin?()
                }
                let minH = contentHeight(forRows: 1)
                let maxH = contentHeight(forRows: ComateStore.recentTaskLimitOptions.max() ?? 10)
                store.customExpandedHeight = min(max(dragBaseHeight + v.translation.height, minH), maxH)
            }
            .onEnded { _ in
                isResizing = false
                let h = store.customExpandedHeight ?? 0
                // 拖到接近默认高度 → 视为恢复默认，避免"设了自定义但看不出区别"
                if abs(h - contentHeight(forRows: displayedRowCount)) <= 2 {
                    store.resetCustomExpandedHeight()
                } else {
                    store.saveCustomExpandedHeight(h)
                }
                interaction.onResizeEnd?()
            }
    }
}
