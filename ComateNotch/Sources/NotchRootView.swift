import SwiftUI
import AppKit

// MARK: - Comate Logo（从 SVG 路径数据还原）

struct ComateLogo: View {
    var size: CGFloat = 20
    var colorful: Bool = true  // false = 白色镂空（tray 图标），true = 彩色填充

    var body: some View {
        if colorful {
            // 彩色：手绘 SVG 路径
            ZStack {
                ComatePath1()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#937EE6"), Color(hex: "#4526BF")],
                            startPoint: .init(x: 0.18, y: 0.97),
                            endPoint: .init(x: 0.50, y: 0.14)
                        )
                    )
                ComatePath2()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF9999"), Color(hex: "#D921B6")],
                            startPoint: .init(x: 0.88, y: 0.19),
                            endPoint: .init(x: 0.33, y: 0.42)
                        )
                    )
            }
            .frame(width: size, height: size)
        } else {
            // 白色镂空：使用 Comate 官方 SVG 路径，白色填充
            ZStack {
                ComatePath1().fill(Color.white)
                ComatePath2().fill(Color.white)
            }
            .frame(width: size, height: size)
        }
    }
}

// 优化：缓存路径避免每帧重算贝塞尔曲线
struct ComatePath1: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 68.0
        var p = Path()
        p.move(to: CGPoint(x: 23.1597*s, y: 6.12598*s))
        p.addCurve(to: CGPoint(x: 46.0126*s, y: 12.0037*s),
                   control1: CGPoint(x: 39.2509*s, y: 7.46566*s),
                   control2: CGPoint(x: 43.2085*s, y: 10.1198*s))
        p.addCurve(to: CGPoint(x: 46.0538*s, y: 12.0326*s),
                   control1: CGPoint(x: 45.4631*s, y: 11.6335*s),
                   control2: CGPoint(x: 46.0538*s, y: 12.0326*s))
        p.addCurve(to: CGPoint(x: 46.1257*s, y: 12.0801*s),
                   control1: CGPoint(x: 46.0866*s, y: 12.0542*s),
                   control2: CGPoint(x: 46.1078*s, y: 12.0702*s))
        p.addCurve(to: CGPoint(x: 46.1762*s, y: 12.1116*s),
                   control1: CGPoint(x: 46.1405*s, y: 12.0918*s),
                   control2: CGPoint(x: 46.149*s, y: 12.0991*s))
        p.addCurve(to: CGPoint(x: 49.2073*s, y: 13.9254*s),
                   control1: CGPoint(x: 46.3883*s, y: 12.2401*s),
                   control2: CGPoint(x: 47.7904*s, y: 13.0769*s))
        p.addCurve(to: CGPoint(x: 49.45*s, y: 14.0725*s),
                   control1: CGPoint(x: 49.45*s, y: 14.0725*s),
                   control2: CGPoint(x: 49.45*s, y: 14.0725*s))
        p.addCurve(to: CGPoint(x: 49.691*s, y: 14.2165*s),
                   control1: CGPoint(x: 49.691*s, y: 14.2165*s),
                   control2: CGPoint(x: 49.691*s, y: 14.2165*s))
        p.addCurve(to: CGPoint(x: 52.3753*s, y: 15.8221*s),
                   control1: CGPoint(x: 51.0153*s, y: 15.0094*s),
                   control2: CGPoint(x: 52.2401*s, y: 15.7424*s))
        p.addCurve(to: CGPoint(x: 52.388*s, y: 15.8307*s),
                   control1: CGPoint(x: 52.388*s, y: 15.8307*s),
                   control2: CGPoint(x: 52.388*s, y: 15.8307*s))
        p.addCurve(to: CGPoint(x: 57.3436*s, y: 21.3746*s),
                   control1: CGPoint(x: 56.0481*s, y: 17.8438*s),
                   control2: CGPoint(x: 57.3436*s, y: 21.3746*s))
        p.addCurve(to: CGPoint(x: 55.3707*s, y: 34.4819*s),
                   control1: CGPoint(x: 58.1472*s, y: 23.5637*s),
                   control2: CGPoint(x: 56.6334*s, y: 29.7544*s))
        p.addCurve(to: CGPoint(x: 55.2487*s, y: 34.9364*s),
                   control1: CGPoint(x: 55.2487*s, y: 34.9364*s),
                   control2: CGPoint(x: 55.2487*s, y: 34.9364*s))
        p.addCurve(to: CGPoint(x: 53.9113*s, y: 40.2693*s),
                   control1: CGPoint(x: 54.5232*s, y: 37.6235*s),
                   control2: CGPoint(x: 53.9121*s, y: 39.7594*s))
        p.addCurve(to: CGPoint(x: 53.2835*s, y: 44.849*s),
                   control1: CGPoint(x: 53.9121*s, y: 40.9079*s),
                   control2: CGPoint(x: 53.652*s, y: 42.8813*s))
        p.addCurve(to: CGPoint(x: 53.2312*s, y: 45.13*s),
                   control1: CGPoint(x: 53.2312*s, y: 45.13*s),
                   control2: CGPoint(x: 53.2312*s, y: 45.13*s))
        p.addCurve(to: CGPoint(x: 51.7505*s, y: 49.6273*s),
                   control1: CGPoint(x: 52.7909*s, y: 47.4216*s),
                   control2: CGPoint(x: 52.2185*s, y: 49.6243*s))
        p.addCurve(to: CGPoint(x: 47.8788*s, y: 49.629*s),
                   control1: CGPoint(x: 50.8653*s, y: 49.6286*s),
                   control2: CGPoint(x: 48.4819*s, y: 49.6286*s))
        p.addCurve(to: CGPoint(x: 45.3462*s, y: 49.6303*s),
                   control1: CGPoint(x: 47.648*s, y: 49.6286*s),
                   control2: CGPoint(x: 46.8065*s, y: 49.629*s))
        p.addCurve(to: CGPoint(x: 44.4826*s, y: 48.1351*s),
                   control1: CGPoint(x: 44.4826*s, y: 48.1351*s),
                   control2: CGPoint(x: 44.4826*s, y: 48.1351*s))
        p.addCurve(to: CGPoint(x: 26.7895*s, y: 25.7503*s),
                   control1: CGPoint(x: 48.7556*s, y: 43.6238*s),
                   control2: CGPoint(x: 33.6883*s, y: 21.7704*s))
        p.addCurve(to: CGPoint(x: 21.5109*s, y: 45.4351*s),
                   control1: CGPoint(x: 19.8908*s, y: 29.7302*s),
                   control2: CGPoint(x: 17.5279*s, y: 38.5417*s))
        p.addCurve(to: CGPoint(x: 25.1763*s, y: 49.4467*s),
                   control1: CGPoint(x: 22.1908*s, y: 46.6119*s),
                   control2: CGPoint(x: 23.4126*s, y: 47.949*s))
        p.addCurve(to: CGPoint(x: 25.5767*s, y: 52.1918*s),
                   control1: CGPoint(x: 25.9805*s, y: 50.1309*s),
                   control2: CGPoint(x: 26.1531*s, y: 51.3052*s))
        p.addCurve(to: CGPoint(x: 17.2217*s, y: 65.0463*s),
                   control1: CGPoint(x: 25.5767*s, y: 52.1918*s),
                   control2: CGPoint(x: 17.2217*s, y: 65.0463*s))
        p.addCurve(to: CGPoint(x: 4.5599*s, y: 55.2144*s),
                   control1: CGPoint(x: 16.5892*s, y: 66.0179*s),
                   control2: CGPoint(x: 14.3133*s, y: 65.6651*s))
        p.addCurve(to: CGPoint(x: 17.0028*s, y: 8.81253*s),
                   control1: CGPoint(x: -4.82725*s, y: 38.9678*s),
                   control2: CGPoint(x: 0.743863*s, y: 18.1924*s))
        p.closeSubpath()
        return p
    }
}

struct ComatePath2: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 68.0
        var p = Path()
        p.move(to: CGPoint(x: 63.4408*s, y: 21.2404*s))
        p.addCurve(to: CGPoint(x: 51.4213*s, y: 65.5945*s),
                   control1: CGPoint(x: 72.3041*s, y: 36.5799*s),
                   control2: CGPoint(x: 67.8315*s, y: 55.9653*s))
        p.addCurve(to: CGPoint(x: 51.3729*s, y: 65.5252*s),
                   control1: CGPoint(x: 52.9063*s, y: 66.4764*s),
                   control2: CGPoint(x: 51.9254*s, y: 66.306*s))
        p.addCurve(to: CGPoint(x: 42.4488*s, y: 51.3124*s),
                   control1: CGPoint(x: 51.4039*s, y: 65.572*s),
                   control2: CGPoint(x: 51.3903*s, y: 65.5473*s))
        p.addCurve(to: CGPoint(x: 42.7513*s, y: 49.5248*s),
                   control1: CGPoint(x: 42.0806*s, y: 50.7242*s),
                   control2: CGPoint(x: 42.2119*s, y: 49.9571*s))
        p.addCurve(to: CGPoint(x: 45.7119*s, y: 46.6361*s),
                   control1: CGPoint(x: 44.1475*s, y: 48.4037*s),
                   control2: CGPoint(x: 45.1335*s, y: 47.4427*s))
        p.addCurve(to: CGPoint(x: 47.5738*s, y: 19.1609*s),
                   control1: CGPoint(x: 51.8123*s, y: 39.3276*s),
                   control2: CGPoint(x: 52.871*s, y: 28.3288*s))
        p.addCurve(to: CGPoint(x: 17.0555*s, y: 8.8981*s),
                   control1: CGPoint(x: 41.1637*s, y: 8.06718*s),
                   control2: CGPoint(x: 27.7724*s, y: 3.68196*s))
        p.addCurve(to: CGPoint(x: 17.0029*s, y: 8.8071*s),
                   control1: CGPoint(x: 17.0555*s, y: 8.8981*s),
                   control2: CGPoint(x: 17.0029*s, y: 8.8071*s))
        p.addCurve(to: CGPoint(x: 63.4408*s, y: 21.2404*s),
                   control1: CGPoint(x: 33.265*s, y: -0.574457*s),
                   control2: CGPoint(x: 54.0538*s, y: 4.99409*s))
        p.closeSubpath()
        return p
    }
}

// MARK: - 状态灯

struct StatusLight: View {
    let color: String
    let size: CGFloat

    init(color: String, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(Color(hex: color))
            .frame(width: size, height: size)
            // 用固定 shadow 替代动态 opacity shadow，减少每帧计算
            .shadow(color: Color(hex: color).opacity(0.5), radius: 3)
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
    @Binding var expanded: Bool
    var onExpandChange: ((Bool) -> Void)?

    // 刘海几何：HUD 总宽必须大于刘海宽，内容仅在左右两翼显示
    var notchWidth: CGFloat
    var wingWidth: CGFloat = 48  // 从 68 缩小到 48
    var notchHeight: CGFloat
    var expandedWidth: CGFloat = 320  // 新增：展开宽度
    var expandedHeight: CGFloat = 280  // 新增：展开高度

    private var collapsedTotalWidth: CGFloat { notchWidth + wingWidth * 2 }

    @State private var hovering = false
    @State private var expandTimer: Timer?
    @State private var isAnimating = false  // 动画期间标记，避免刷新干扰
    private let forceExpanded = CommandLine.arguments.contains("--expanded")

    // logo 在整个窗口中的固定坐标（收起/展开态一致）
    private var logoPosition: CGPoint {
        CGPoint(x: wingWidth / 2, y: notchHeight / 2)
    }

    var body: some View {
        ZStack {
            // 层 1：背景形状（收起/展开切换）
            if expanded {
                expandedBackground
            } else {
                collapsedBackground
            }
            // 层 2：固定位置的 logo + 状态灯（位置不变，只变颜色）
            logoOverlay
            // 层 3：右翼内容（收起态 = plus 按钮，展开态 = 任务列表）
            if expanded {
                expandedContent
                    .transition(.opacity)
            } else {
                collapsedRightWing
                    .transition(.opacity)
            }
        }
        .frame(
            width: expanded ? expandedWidth : collapsedTotalWidth,
            height: expanded ? expandedHeight : notchHeight
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.9), value: expanded)
        .onHover { isHovering in
            hovering = isHovering
            if forceExpanded { return }
            if isHovering {
                expandTimer?.invalidate()
                expandTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                    DispatchQueue.main.async {
                        isAnimating = true
                        store.isPaused = true
                        withAnimation { expanded = true }
                        onExpandChange?(true)
                        // 动画结束后恢复刷新
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isAnimating = false
                            store.isPaused = false
                        }
                    }
                }
            } else {
                expandTimer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if !hovering {
                        isAnimating = true
                        store.isPaused = true
                        withAnimation { expanded = false }
                        onExpandChange?(false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isAnimating = false
                            store.isPaused = false
                        }
                    }
                }
            }
        }
        .onAppear {
            if forceExpanded { expanded = true; onExpandChange?(true) }
        }
    }

    // MARK: - 收起态背景
    private var collapsedBackground: some View {
        HStack(spacing: 0) {
            Color.black.frame(width: wingWidth)       // 左翼底色
            Color.black.frame(width: notchWidth)       // 中段（刘海遮挡）
            Color.black.frame(width: wingWidth)       // 右翼底色
        }
        .frame(width: collapsedTotalWidth, height: notchHeight)
        .background(NotchShape(cornerRadius: 14).fill(Color.black))
        .clipShape(NotchShape(cornerRadius: 14))
        .contentShape(NotchShape(cornerRadius: 14))
        .drawingGroup()
    }

    // MARK: - 展开态背景
    private var expandedBackground: some View {
        NotchShape(cornerRadius: 16)
            .fill(Color.black)
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            .frame(width: expandedWidth, height: expandedHeight)
            .clipShape(NotchShape(cornerRadius: 16))
    }

    // MARK: - 固定位置 logo + 状态灯
    /// 始终锚定在收起态左翼的同一坐标，展开/收起只切换颜色
    private var logoOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            ComateLogo(size: 18, colorful: expanded)  // 收起=白，展开=彩色
            Circle()
                .fill(Color(hex: store.primaryLight.color))
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.8))
                .shadow(
                    color: store.primaryLight != .gray
                        ? Color(hex: store.primaryLight.color).opacity(store.primaryLight == .red ? 0.9 : 0.65)
                        : .clear,
                    radius: store.primaryLight != .gray ? 5 : 0
                )
        }
        .position(x: logoPosition.x, y: logoPosition.y)
    }

    // MARK: - 收起态右翼（plus 按钮）
    private var collapsedRightWing: some View {
        Button(action: { store.launchNewSession() }) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
        }
        .buttonStyle(.plain)
        .position(
            x: collapsedTotalWidth - wingWidth / 2,
            y: notchHeight / 2
        )
    }

    // MARK: - 展开态内容（任务列表）
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 顶部留出 logo 区域 + 状态标签
            HStack {
                Spacer()
                let count = store.runningTasks.count
                if count > 0 {
                    Text("\(count) 运行中")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Color(hex: "#FFB800").opacity(0.22), in: Capsule())
                        .foregroundStyle(Color(hex: "#FFB800"))
                } else {
                    Text("空闲")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Divider().background(Color.white.opacity(0.10))

            if store.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(store.recentTasks.prefix(6)) { task in
                            taskRow(task)
                                .onTapGesture { store.openSession(task) }
                                .onHover { h in
                                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                        }
                    }
                }
            }

            HStack(spacing: 3) {
                Circle()
                    .fill(Color(hex: store.primaryLight.color))
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: store.primaryLight != .gray
                            ? Color(hex: store.primaryLight.color).opacity(store.primaryLight == .red ? 0.9 : 0.65)
                            : .clear,
                        radius: store.primaryLight != .gray ? 5 : 0
                    )
                Text("实时同步 · \(timeStr(store.lastRefreshed))")
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Button(action: { store.launchComate() }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
        }
        .padding(.horizontal, 12)
        // 顶部 padding：避开刘海 + 给 logo 留空间（logo 在 y=notchHeight/2）
        .padding(.top, notchHeight / 2 + 12)
        .padding(.bottom, 12)
        .frame(width: expandedWidth, height: expandedHeight)
    }

    private func taskRow(_ t: ComateTask) -> some View {
        HStack(spacing: 8) {
            StatusLight(color: t.light.color, size: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title.isEmpty ? "（无标题）" : t.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(t.statusLabel)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: t.light.color))
                    Text("\(t.messageCount) 条消息")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(relTime(t.updatedAt))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }

    private func relTime(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "\(s)秒前" }
        if s < 3600 { return "\(s/60)分钟前" }
        if s < 86400 { return "\(s/3600)小时前" }
        return "\(s/86400)天前"
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
