import SwiftUI
import AppKit

// MARK: - Comate Logo（使用官方 SVG 路径，无锯齿矢量渲染）

struct ComateLogo: View {
    var size: CGFloat = 20
    var colorful: Bool = true

    var body: some View {
        ZStack {
            ComateOfficialPath1()
                .fill(colorful
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#937EE6"), Color(hex: "#4526BF")],
                        startPoint: .init(x: 0.18, y: 0.97),
                        endPoint: .init(x: 0.50, y: 0.14)))
                    : AnyShapeStyle(Color.white))
            ComateOfficialPath2()
                .fill(colorful
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#FF9999"), Color(hex: "#D921B6")],
                        startPoint: .init(x: 0.88, y: 0.19),
                        endPoint: .init(x: 0.33, y: 0.42)))
                    : AnyShapeStyle(Color.white))
        }
        .frame(width: size, height: size)

    }
}

// MARK: - 官方 SVG Path 1（从 logo_white.svg 提取）
// viewBox="0 0 68 68", fill-rule="evenodd"
struct ComateOfficialPath1: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 68.0
        let sy = rect.height / 68.0
        var p = Path()
        p.move(to: CGPoint(x: 23.1597*sx, y: 6.12598*sy))
        p.addLine(to: CGPoint(x: 39.2509*sx, y: 7.46566*sy))
        p.addCurve(to: CGPoint(x: 46.0126*sx, y: 12.0037*sy),
                   control1: CGPoint(x: 43.2085*sx, y: 10.1198*sy),
                   control2: CGPoint(x: 45.4631*sx, y: 11.6335*sy))
        p.addLine(to: CGPoint(x: 46.0538*sx, y: 12.0326*sy))
        p.addCurve(to: CGPoint(x: 46.1257*sx, y: 12.0801*sy),
                   control1: CGPoint(x: 46.0866*sx, y: 12.0542*sy),
                   control2: CGPoint(x: 46.1078*sx, y: 12.0702*sy))
        p.addLine(to: CGPoint(x: 46.1405*sx, y: 12.0918*sy))
        p.addLine(to: CGPoint(x: 46.149*sx, y: 12.0991*sy))
        p.addLine(to: CGPoint(x: 46.1762*sx, y: 12.1116*sy))
        p.addCurve(to: CGPoint(x: 49.2073*sx, y: 13.9254*sy),
                   control1: CGPoint(x: 46.3883*sx, y: 12.2401*sy),
                   control2: CGPoint(x: 47.7904*sx, y: 13.0769*sy))
        p.addLine(to: CGPoint(x: 49.45*sx, y: 14.0725*sy))
        p.addLine(to: CGPoint(x: 49.691*sx, y: 14.2165*sy))
        p.addCurve(to: CGPoint(x: 52.3753*sx, y: 15.8221*sy),
                   control1: CGPoint(x: 51.0153*sx, y: 15.0094*sy),
                   control2: CGPoint(x: 52.2401*sx, y: 15.7424*sy))
        p.addLine(to: CGPoint(x: 52.388*sx, y: 15.8307*sy))
        p.addCurve(to: CGPoint(x: 57.3436*sx, y: 21.3746*sy),
                   control1: CGPoint(x: 52.388*sx, y: 15.8307*sy),
                   control2: CGPoint(x: 56.0481*sx, y: 17.8438*sy))
        p.addCurve(to: CGPoint(x: 55.3707*sx, y: 34.4819*sy),
                   control1: CGPoint(x: 58.1472*sx, y: 23.5637*sy),
                   control2: CGPoint(x: 56.6334*sx, y: 29.7544*sy))
        p.addLine(to: CGPoint(x: 55.2487*sx, y: 34.9364*sy))
        p.addCurve(to: CGPoint(x: 53.9113*sx, y: 40.2693*sy),
                   control1: CGPoint(x: 54.5232*sx, y: 37.6235*sy),
                   control2: CGPoint(x: 53.9121*sx, y: 39.7594*sy))
        p.addCurve(to: CGPoint(x: 53.2835*sx, y: 44.849*sy),
                   control1: CGPoint(x: 53.9121*sx, y: 40.9079*sy),
                   control2: CGPoint(x: 53.652*sx, y: 42.8813*sy))
        p.addLine(to: CGPoint(x: 53.2312*sx, y: 45.13*sy))
        p.addCurve(to: CGPoint(x: 51.7505*sx, y: 49.6273*sy),
                   control1: CGPoint(x: 52.7909*sx, y: 47.4216*sy),
                   control2: CGPoint(x: 52.2185*sx, y: 49.6243*sy))
        p.addCurve(to: CGPoint(x: 47.8788*sx, y: 49.629*sy),
                   control1: CGPoint(x: 50.8653*sx, y: 49.6286*sy),
                   control2: CGPoint(x: 48.4819*sx, y: 49.6286*sy))
        p.addLine(to: CGPoint(x: 45.3462*sx, y: 49.6303*sy))
        p.addLine(to: CGPoint(x: 44.4826*sx, y: 48.1351*sy))
        p.addCurve(to: CGPoint(x: 46.4899*sx, y: 31.0249*sy),
                   control1: CGPoint(x: 48.7556*sx, y: 43.6238*sy),
                   control2: CGPoint(x: 49.756*sx, y: 36.6779*sy))
        p.addCurve(to: CGPoint(x: 26.7895*sx, y: 25.7503*sy),
                   control1: CGPoint(x: 42.5068*sx, y: 24.1315*sy),
                   control2: CGPoint(x: 33.6883*sx, y: 21.7704*sy))
        p.addCurve(to: CGPoint(x: 21.5109*sx, y: 45.4351*sy),
                   control1: CGPoint(x: 19.8908*sx, y: 29.7302*sy),
                   control2: CGPoint(x: 17.5279*sx, y: 38.5417*sy))
        p.addCurve(to: CGPoint(x: 25.1763*sx, y: 49.4467*sy),
                   control1: CGPoint(x: 22.1908*sx, y: 46.6119*sy),
                   control2: CGPoint(x: 23.4126*sx, y: 47.949*sy))
        p.addCurve(to: CGPoint(x: 25.5767*sx, y: 52.1918*sy),
                   control1: CGPoint(x: 25.9805*sx, y: 50.1309*sy),
                   control2: CGPoint(x: 26.1531*sx, y: 51.3052*sy))
        p.addLine(to: CGPoint(x: 17.2217*sx, y: 65.0463*sy))
        p.addCurve(to: CGPoint(x: 14.3133*sx, y: 65.6651*sy),
                   control1: CGPoint(x: 16.5892*sx, y: 66.0179*sy),
                   control2: CGPoint(x: 15.2855*sx, y: 66.2971*sy))
        p.addCurve(to: CGPoint(x: 14.1061*sx, y: 65.5096*sy),
                   control1: CGPoint(x: 14.2414*sx, y: 65.6175*sy),
                   control2: CGPoint(x: 14.1707*sx, y: 65.5652*sy))
        p.addCurve(to: CGPoint(x: 4.5599*sx, y: 55.2144*sy),
                   control1: CGPoint(x: 8.76154*sx, y: 61.6786*sy),
                   control2: CGPoint(x: 6.26313*sx, y: 58.1622*sy))
        p.addCurve(to: CGPoint(x: 17.0028*sx, y: 8.81253*sy),
                   control1: CGPoint(x: -4.82725*sx, y: 38.9678*sy),
                   control2: CGPoint(x: 0.743863*sx, y: 18.1924*sy))
        p.closeSubpath()
        return p
    }
}

// MARK: - 官方 SVG Path 2（从 logo_white.svg 提取）
struct ComateOfficialPath2: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 68.0
        let sy = rect.height / 68.0
        var p = Path()
        p.move(to: CGPoint(x: 63.4408*sx, y: 21.2404*sy))
        p.addCurve(to: CGPoint(x: 53.6203*sx, y: 65.9753*sy),
                   control1: CGPoint(x: 72.3041*sx, y: 36.5799*sy),
                   control2: CGPoint(x: 67.8315*sx, y: 55.9653*sy))
        p.addCurve(to: CGPoint(x: 51.3729*sx, y: 65.5252*sy),
                   control1: CGPoint(x: 52.9063*sx, y: 66.4764*sy),
                   control2: CGPoint(x: 51.9254*sx, y: 66.306*sy))
        p.addLine(to: CGPoint(x: 42.4488*sx, y: 51.3124*sy))
        p.addCurve(to: CGPoint(x: 42.7513*sx, y: 49.5248*sy),
                   control1: CGPoint(x: 42.0806*sx, y: 50.7242*sy),
                   control2: CGPoint(x: 42.2119*sx, y: 49.9571*sy))
        p.addCurve(to: CGPoint(x: 45.7119*sx, y: 46.6361*sy),
                   control1: CGPoint(x: 44.1475*sx, y: 48.4037*sy),
                   control2: CGPoint(x: 45.1335*sx, y: 47.4427*sy))
        p.addCurve(to: CGPoint(x: 47.5738*sx, y: 19.1609*sy),
                   control1: CGPoint(x: 51.8123*sx, y: 39.3276*sy),
                   control2: CGPoint(x: 52.871*sx, y: 28.3288*sy))
        p.addCurve(to: CGPoint(x: 17.0555*sx, y: 8.8981*sy),
                   control1: CGPoint(x: 41.1637*sx, y: 8.06718*sy),
                   control2: CGPoint(x: 27.7724*sx, y: 3.68196*sy))
        p.addLine(to: CGPoint(x: 17.0029*sx, y: 8.8071*sy))
        p.addCurve(to: CGPoint(x: 63.4408*sx, y: 21.2404*sy),
                   control1: CGPoint(x: 33.265*sx, y: -0.574457*sy),
                   control2: CGPoint(x: 54.0538*sx, y: 4.99409*sy))
        p.closeSubpath()
        return p
    }
}

// MARK: - 状态灯

struct StatusLight: View {
    let color: String
    let size: CGFloat
    /// 闪烁：用于「等你确认」这类需要打断你的状态（红闪）；异常是常亮
    let blinking: Bool
    @State private var dimmed = false

    init(color: String, size: CGFloat = 8, blinking: Bool = false) {
        self.color = color
        self.size = size
        self.blinking = blinking
    }

    var body: some View {
        Circle()
            .fill(Color(hex: color))
            .frame(width: size, height: size)
            // 用固定 shadow 替代动态 opacity shadow，减少每帧计算
            .shadow(color: Color(hex: color).opacity(0.5), radius: 3)
            .opacity(blinking && dimmed ? 0.2 : 1)
            .onAppear { restart() }
            .onChange(of: blinking) { _ in restart() }
    }

    /// repeatForever 动画不会自己停，换状态时必须显式重置，否则会叠加多个动画
    private func restart() {
        dimmed = false
        guard blinking else { return }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
            dimmed = true
        }
    }
}

// MARK: - 刘海形状（顶部外圆角/凹弧 + 底部凸圆角）

struct NotchShape: Shape {
    var cornerRadius: CGFloat = 16  // PDF: expanded r=16, compact r=14

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, w / 2, h / 2)  // 确保圆角不超过尺寸的一半
        var p = Path()

        // 顶部：平直（与屏幕边缘齐平，无圆角）
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        
        // 右侧：垂直向下到底部圆角起点
        p.addLine(to: CGPoint(x: w, y: h - r))
        
        // 右下角：标准圆角
        p.addArc(center: CGPoint(x: w - r, y: h - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        
        // 底部：水平向左
        p.addLine(to: CGPoint(x: r, y: h))
        
        // 左下角：标准圆角
        p.addArc(center: CGPoint(x: r, y: h - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        // 左侧：垂直向上回到起点
        p.addLine(to: CGPoint(x: 0, y: 0))

        return p
    }
}

// MARK: - 主视图

struct NotchRootView: View {
    @ObservedObject var store: ComateStore
    var initialExpanded: Bool = false
    /// 展开/收起回调：第二个参数为展开态目标高度（由内容自适应或用户拖拽决定）
    var onExpandChange: ((Bool, CGFloat) -> Void)?

    // 刘海几何：HUD 总宽必须大于刘海宽，内容仅在左右两翼显示
    var wingWidth: CGFloat = 36  // 收窄到 36
    var notchHeight: CGFloat
    var expandedWidth: CGFloat = 280
    /// hostingView 画布高度：根视图必须显式撑满它并左上对齐，
    /// 否则 NSHostingView 会把根视图垂直居中（偏移 (画布高-内容高)/2），
    /// 表现为整个 HUD 在窗口里被往下推。
    var canvasHeight: CGFloat = 720
    /// 拖拽调整高度时立即同步窗口尺寸（不走动画，跟手）
    var onExpandedHeightChange: ((CGFloat) -> Void)?
    /// 拖拽开始：参数为拖拽期间窗口应先撑到的最大高度
    var onResizeBegin: ((CGFloat) -> Void)?
    /// 拖拽结束：按最终高度收一次窗口
    var onResizeEnd: ((CGFloat) -> Void)?
    /// 设置按钮：弹出与右键完全一致的菜单（菜单定义与悬浮模式共用同一份）
    var onShowMenu: (() -> Void)?

    /// 收起态与展开态同宽：宽度全程不变，动画只改变 y 与高度，
    /// 左右边缘完全不动（否则两态差 1px 会看起来"右边没对齐"）。
    private var collapsedTotalWidth: CGFloat { expandedWidth }

    @State private var hovering = false
    @State private var expandTimer: Timer?
    @State private var isAnimating = false
    @State private var expanded: Bool = false

    /// 实测：列表行 VStack 自然高度 + 该测量对应的行数（用于反推单行占高）
    @State private var rowsHeight: CGFloat = 0
    @State private var measuredRowCount: Int = 0
    /// 实测：页脚高度
    @State private var footerHeight: CGFloat = 0
    /// 拖拽状态
    @State private var isResizing = false
    @State private var resizeHovered = false
    @State private var dragBaseHeight: CGFloat = 0

    /// 布局计算与常量都集中在 NotchLayout（高度公式与 padding 必须同源，
    /// 否则改了一处漏一处就会表现为「内容被裁掉一截」）
    private var layout: NotchLayout { NotchLayout(notchHeight: notchHeight) }
    private var horizontalPadding: CGFloat { NotchLayout.horizontalPadding }
    private var listSpacing: CGFloat { NotchLayout.listSpacing }
    private var bottomPadding: CGFloat { NotchLayout.bottomPadding }
    private var resizeHandleHeight: CGFloat { NotchLayout.resizeHandleHeight }
    private var resizeHitHeight: CGFloat { NotchLayout.resizeHitHeight }
    private var emptyPlaceholderHeight: CGFloat { NotchLayout.emptyPlaceholderHeight }
    private var topInset: CGFloat { layout.topInset }

    /// 当前实际展示的记录条数
    private var displayedRowCount: Int { min(store.recentTaskLimit, store.recentTasks.count) }

    /// 单行占高（行高 + 行间距）：由实测行高反推。
    /// 它只取决于行本身，与当前展示多少条无关，所以切换条数时依然有效。
    private var rowUnit: CGFloat {
        NotchLayout.rowUnit(rowsHeight: rowsHeight, measuredRowCount: measuredRowCount)
    }

    /// 指定条数时面板应有的高度（即内容自适应高度）
    private func contentHeight(forRows rows: Int) -> CGFloat {
        layout.contentHeight(forRows: rows, rowUnit: rowUnit, footerHeight: footerHeight)
    }

    /// 自然高度：跟随当前条数
    private var naturalContentHeight: CGFloat { contentHeight(forRows: displayedRowCount) }
    /// 最小高度 = 1 条记录的高度
    private var minExpandedHeight: CGFloat { contentHeight(forRows: 1) }
    /// 最大高度 = 10 条记录的高度
    private var maxExpandedHeight: CGFloat {
        contentHeight(forRows: NotchLayout.maxRowCount)
    }

    /// 展开态实际高度：自定义高度被夹在 [1 条, 10 条] 之间；未自定义时跟随内容
    private var targetExpandedHeight: CGFloat {
        layout.clampedHeight(store.customExpandedHeight ?? naturalContentHeight,
                             rowUnit: rowUnit, footerHeight: footerHeight)
    }

    /// 列表可视高度：装得下就贴合内容，装不下则裁剪并可滚动
    private var listViewportHeight: CGFloat {
        layout.listViewportHeight(targetExpandedHeight: targetExpandedHeight,
                                  rowsHeight: rowsHeight, footerHeight: footerHeight)
    }

    /// 拖拽底部手柄调整展开高度（顶部锚定不动，向下拖变高）
    /// 必须用 .global 坐标空间：手柄本身会跟着面板底边移动，
    /// 用默认的 .local 时 translation 会被手柄自身位移抵消，
    /// 表现为底边追着鼠标抖、跟不走。
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { v in
                if !isResizing {
                    isResizing = true
                    dragBaseHeight = targetExpandedHeight
                    // 拖拽期间窗口先撑到最大，之后只改 SwiftUI 内容高度，
                    // 避免每次鼠标移动都 setFrame（卡顿且与内容互相拉扯）
                    onResizeBegin?(maxExpandedHeight)
                }
                let h = min(max(dragBaseHeight + v.translation.height, minExpandedHeight),
                            maxExpandedHeight)
                store.customExpandedHeight = h
            }
            .onEnded { _ in
                isResizing = false
                let h = store.customExpandedHeight ?? 0
                // 拖到恰好等于默认高度 → 视为恢复默认，避免"设了自定义但看不出区别"
                if abs(h - naturalContentHeight) <= 1 {
                    store.resetCustomExpandedHeight()
                } else {
                    store.saveCustomExpandedHeight(h)
                }
                onResizeEnd?(targetExpandedHeight)
            }
    }

    var body: some View {
        let currentWidth = expanded ? expandedWidth : collapsedTotalWidth
        let currentHeight = expanded ? targetExpandedHeight : notchHeight
        let cornerR: CGFloat = 14

        NotchShape(cornerRadius: cornerR)
            .fill(Color.black)
            .frame(width: currentWidth, height: currentHeight)
            // 叠加层：logo + 状态灯（与悬浮模式共用 HUDLogoBadge）
            .overlay(alignment: .topLeading) {
                HUDLogoBadge(store: store, logoSize: 18, lightSize: 6, colorful: expanded)
                    .position(x: wingWidth / 2, y: notchHeight / 2)
            }
            // 叠加层：+号按钮（右翼，收起态）
            .overlay(alignment: .topTrailing) {
                ComatePlusButton {
                    store.openNewTask()
                }
                .padding(.trailing, wingWidth / 2 - 2)
                .padding(.top, (notchHeight - 18) / 2)
            }
            // 展开内容：按内容自然高度布局、顶部对齐。
            // 收起时无需额外裁剪/透明：内容顶部内边距(notchHeight/2+24) 已大于
            // 收起态高度，窗口裁剪就足以隐藏它。
            .overlay(alignment: .topLeading) {
                expandedContent
            }
            // 拖拽手柄：展开态底部，拖动可自定义面板高度
            .overlay(alignment: .bottom) {
                if expanded {
                    ZStack {
                        // 命中区只取面板最底部一条：满高命中会盖住页脚按钮
                        Color.clear
                            .frame(height: resizeHitHeight)
                            .contentShape(Rectangle())
                        Capsule()
                            .fill(Color.white.opacity(resizeHovered || isResizing ? 0.5 : 0.22))
                            .frame(width: 44, height: 4)
                            .padding(.bottom, 4)
                    }
                    .frame(height: resizeHandleHeight, alignment: .bottom)
                    .onHover { h in
                        guard h != resizeHovered else { return }
                        resizeHovered = h
                        if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                    }
                    .gesture(resizeGesture)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: store.primaryLight)
            .animation(isResizing ? nil : Animation.easeInOut(duration: 0.25), value: expanded)
            // 拖拽时去掉高度动画，保证跟手
            .animation(isResizing ? nil : Animation.easeInOut(duration: 0.25), value: currentHeight)
            // 高度变化（测量完成 / 切换条数 / 恢复默认）→ 同步窗口高度；
            // 拖拽中窗口已撑到最大高度，松手时由 onResizeEnd 统一收口
            .onChange(of: targetExpandedHeight) { _ in
                guard expanded, !isResizing else { return }
                onExpandedHeightChange?(targetExpandedHeight)
            }
            .onHover { isHovering in
            hovering = isHovering
            if isHovering {
                // 鼠标进入：如果收起则展开
                expandTimer?.invalidate()
                guard !expanded else { return }
                expandTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                    DispatchQueue.main.async {
                        guard !self.expanded else { return }
                        isAnimating = true
                        store.isPaused = true
                        withAnimation { expanded = true }
                        onExpandChange?(true, self.targetExpandedHeight)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isAnimating = false
                            store.isPaused = false
                        }
                    }
                }
            } else {
                // 鼠标离开：如果展开则收起
                expandTimer?.invalidate()
                guard expanded else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    // 拖拽调高度期间即使指针短暂移出窗口也不要收起
                    guard !self.hovering, self.expanded, !self.isResizing else { return }
                    isAnimating = true
                    store.isPaused = true
                    withAnimation { expanded = false }
                    onExpandChange?(false, self.targetExpandedHeight)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isAnimating = false
                        store.isPaused = false
                    }
                }
            }
        }
        .onAppear {
            NSLog("[NotchRootView] onAppear: initialExpanded=%@ expanded_before=%@", String(describing: initialExpanded), String(describing: expanded))
            expanded = initialExpanded
            NSLog("[NotchRootView] onAppear: expanded_after=%@", String(describing: expanded))
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onExpandChange?(true, self.targetExpandedHeight)
                }
            }
        }
        // 显式撑满 hostingView 画布并左上对齐：
        // 根视图比画布小的话 NSHostingView 会垂直居中，导致 HUD 整体下移。
        .frame(width: expandedWidth, height: canvasHeight, alignment: .topLeading)
    }

    // MARK: - 展开内容（始终在视图树中，通过 opacity 显隐）
    private var expandedContent: some View {
        listSection
            // 列表高度固定：超出时由 ScrollView 滚动，不撑高面板
            .frame(height: listSectionHeight, alignment: .topLeading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topInset)
            // 高度固定为当前面板高度
            .frame(width: expandedWidth, height: targetExpandedHeight, alignment: .topLeading)
            // 页脚绝对吸底：位置只由面板高度决定，与列表实际高度无关。
            // 之前用 Spacer(minLength: 0) 顶到尾部，但 VStack 的 spacing 会围绕
            // Spacer 各插一条间距，导致列表被裁短时内容比面板高 6pt，
            // 页脚被挤到面板下沿外（底部留白失效），热区又被拖拽手柄压掉大半。
            .overlay(alignment: .bottom) {
                HUDUsageFooter(store: store, onSettings: { onShowMenu?() })
                    // 实测页脚高度（用于反推内容高度）
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: FooterHeightKey.self, value: g.size.height)
                        }
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
            }
            .onPreferenceChange(RowsHeightKey.self) { h in
                guard h > 0, abs(h - rowsHeight) > 0.5 else { return }
                rowsHeight = h
                measuredRowCount = displayedRowCount
            }
            .onPreferenceChange(FooterHeightKey.self) { h in
                guard h > 0, abs(h - footerHeight) > 0.5 else { return }
                footerHeight = h
            }
    }

    /// 列表区：有记录时是可滚动列表，无记录时是占位文案
    private var listSection: some View {
        Group {
            if store.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    HUDTaskRows(store: store, spacing: listSpacing)
                    // 实测行 VStack 自然高度（与面板高度无关）
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: RowsHeightKey.self, value: g.size.height)
                        }
                    )
                }
            }
        }
    }

    /// 列表区高度：无记录时没有行可测，给占位文案一个固定高度
    private var listSectionHeight: CGFloat {
        store.recentTasks.isEmpty ? emptyPlaceholderHeight : listViewportHeight
    }
}
// MARK: - ComateTaskRow
struct ComateTaskRow: View {
    let task: ComateTask
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            StatusLight(color: task.light.color, size: 7,
                        blinking: task.redKind == .waitingConfirmation)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: task.sourceIcon)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(task.isCloud ? 0.55 : 0.4))
                        .help(task.isCloud ? "云端托管" : "workspace")
                    Text(task.title.isEmpty ? "（无标题）" : task.title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.92))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(task.statusLabel)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: task.light.color))
                    Text(task.metaLabel)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(relTime(task.updatedAt))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(isHovered ? 0.5 : 0.2))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(isHovered ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 8))
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture { onTap() }
        // 等确认时把具体问题带出来（行里放不下，做成悬停提示）
        .help(task.hoverHelp)
    }

    private func relTime(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "\(s)秒前" }
        if s < 3600 { return "\(s/60)分钟前" }
        if s < 86400 { return "\(s/3600)小时前" }
        return "\(s/86400)天前"
    }
}

// MARK: - ComatePlusButton
struct ComatePlusButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.white.opacity(isHovered ? 0.85 : 0.55))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

/// 列表行 VStack 自然高度 / 页脚高度上报：用于反推 1 条与 10 条时应有的面板高度
private struct RowsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FooterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Color hex

extension Color {
    init(hex: String) {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
