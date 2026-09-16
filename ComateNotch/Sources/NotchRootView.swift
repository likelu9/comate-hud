import SwiftUI
import AppKit

// MARK: - Comate Logo（从 SVG 路径数据还原）

struct ComateLogo: View {
    var size: CGFloat = 20

    var body: some View {
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
    }
}

struct ComatePath1: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = rect.width / 68.0
        p.move(to: CGPoint(x: 23.16*s, y: 6.13*s))
        p.addLine(to: CGPoint(x: 39.25*s, y: 7.47*s))
        p.addCurve(to: CGPoint(x: 46.01*s, y: 12.00*s),
                   control1: CGPoint(x: 43.21*s, y: 10.12*s),
                   control2: CGPoint(x: 45.46*s, y: 11.63*s))
        p.addLine(to: CGPoint(x: 46.05*s, y: 12.03*s))
        p.addCurve(to: CGPoint(x: 46.13*s, y: 12.08*s),
                   control1: CGPoint(x: 46.09*s, y: 12.05*s),
                   control2: CGPoint(x: 46.11*s, y: 12.07*s))
        p.addLine(to: CGPoint(x: 46.15*s, y: 12.09*s))
        p.addLine(to: CGPoint(x: 46.15*s, y: 12.10*s))
        p.addCurve(to: CGPoint(x: 49.21*s, y: 13.93*s),
                   control1: CGPoint(x: 46.39*s, y: 12.24*s),
                   control2: CGPoint(x: 47.79*s, y: 13.08*s))
        p.addLine(to: CGPoint(x: 49.45*s, y: 14.07*s))
        p.addLine(to: CGPoint(x: 49.69*s, y: 14.22*s))
        p.addCurve(to: CGPoint(x: 52.38*s, y: 15.82*s),
                   control1: CGPoint(x: 51.02*s, y: 15.01*s),
                   control2: CGPoint(x: 52.24*s, y: 15.74*s))
        p.addLine(to: CGPoint(x: 52.39*s, y: 15.83*s))
        p.addCurve(to: CGPoint(x: 57.34*s, y: 21.37*s),
                   control1: CGPoint(x: 56.05*s, y: 17.84*s),
                   control2: CGPoint(x: 57.34*s, y: 21.37*s))
        p.addCurve(to: CGPoint(x: 55.37*s, y: 34.48*s),
                   control1: CGPoint(x: 58.15*s, y: 23.56*s),
                   control2: CGPoint(x: 56.63*s, y: 29.75*s))
        p.addLine(to: CGPoint(x: 55.25*s, y: 34.94*s))
        p.addCurve(to: CGPoint(x: 53.91*s, y: 40.27*s),
                   control1: CGPoint(x: 54.52*s, y: 37.62*s),
                   control2: CGPoint(x: 53.91*s, y: 39.76*s))
        p.addCurve(to: CGPoint(x: 53.28*s, y: 44.85*s),
                   control1: CGPoint(x: 53.91*s, y: 40.91*s),
                   control2: CGPoint(x: 53.65*s, y: 42.88*s))
        p.addLine(to: CGPoint(x: 53.23*s, y: 45.13*s))
        p.addCurve(to: CGPoint(x: 51.75*s, y: 49.63*s),
                   control1: CGPoint(x: 52.79*s, y: 47.42*s),
                   control2: CGPoint(x: 52.22*s, y: 49.62*s))
        p.addCurve(to: CGPoint(x: 45.35*s, y: 49.63*s),
                   control1: CGPoint(x: 50.87*s, y: 49.63*s),
                   control2: CGPoint(x: 46.81*s, y: 49.63*s))
        p.addLine(to: CGPoint(x: 44.48*s, y: 48.14*s))
        p.addCurve(to: CGPoint(x: 26.79*s, y: 25.75*s),
                   control1: CGPoint(x: 48.76*s, y: 43.62*s),
                   control2: CGPoint(x: 33.69*s, y: 21.77*s))
        p.addCurve(to: CGPoint(x: 21.51*s, y: 45.44*s),
                   control1: CGPoint(x: 19.89*s, y: 29.73*s),
                   control2: CGPoint(x: 17.53*s, y: 38.54*s))
        p.addCurve(to: CGPoint(x: 25.18*s, y: 49.45*s),
                   control1: CGPoint(x: 22.19*s, y: 46.61*s),
                   control2: CGPoint(x: 23.41*s, y: 47.95*s))
        p.addCurve(to: CGPoint(x: 25.58*s, y: 52.19*s),
                   control1: CGPoint(x: 25.98*s, y: 50.13*s),
                   control2: CGPoint(x: 26.15*s, y: 51.31*s))
        p.addLine(to: CGPoint(x: 17.22*s, y: 65.05*s))
        p.addCurve(to: CGPoint(x: 14.11*s, y: 65.51*s),
                   control1: CGPoint(x: 16.59*s, y: 66.02*s),
                   control2: CGPoint(x: 15.29*s, y: 66.30*s))
        p.addCurve(to: CGPoint(x: 4.56*s, y: 55.21*s),
                   control1: CGPoint(x: 14.24*s, y: 65.62*s),
                   control2: CGPoint(x: 6.26*s, y: 58.16*s))
        p.addCurve(to: CGPoint(x: 17.00*s, y: 8.81*s),
                   control1: CGPoint(x: -4.83*s, y: 38.97*s),
                   control2: CGPoint(x: 0.74*s, y: 18.19*s))
        p.closeSubpath()
        return p
    }
}

struct ComatePath2: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = rect.width / 68.0
        p.move(to: CGPoint(x: 63.44*s, y: 21.24*s))
        p.addCurve(to: CGPoint(x: 51.42*s, y: 65.59*s),
                   control1: CGPoint(x: 72.30*s, y: 36.58*s),
                   control2: CGPoint(x: 67.83*s, y: 55.97*s))
        p.addCurve(to: CGPoint(x: 42.45*s, y: 51.31*s),
                   control1: CGPoint(x: 51.40*s, y: 65.55*s),
                   control2: CGPoint(x: 51.93*s, y: 66.31*s))
        p.addCurve(to: CGPoint(x: 45.71*s, y: 46.64*s),
                   control1: CGPoint(x: 42.08*s, y: 50.72*s),
                   control2: CGPoint(x: 42.21*s, y: 49.96*s))
        p.addCurve(to: CGPoint(x: 47.57*s, y: 19.16*s),
                   control1: CGPoint(x: 51.81*s, y: 39.33*s),
                   control2: CGPoint(x: 52.87*s, y: 28.33*s))
        p.addCurve(to: CGPoint(x: 17.06*s, y: 8.90*s),
                   control1: CGPoint(x: 41.16*s, y: 8.07*s),
                   control2: CGPoint(x: 27.77*s, y: 3.68*s))
        p.addLine(to: CGPoint(x: 17.00*s, y: 8.81*s))
        p.addCurve(to: CGPoint(x: 63.44*s, y: 21.24*s),
                   control1: CGPoint(x: 33.27*s, y: -0.57*s),
                   control2: CGPoint(x: 54.05*s, y: 4.99*s))
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
            .shadow(color: Color(hex: color).opacity(0.8), radius: 4)
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
    private let forceExpanded = CommandLine.arguments.contains("--expanded")

    var body: some View {
        ZStack(alignment: .top) {
            if expanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: expanded)
        .onHover { isHovering in
            hovering = isHovering
            if forceExpanded { return }
            if isHovering {
                expandTimer?.invalidate()
                expandTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { _ in
                    DispatchQueue.main.async {
                        withAnimation { expanded = true }
                        onExpandChange?(true)
                    }
                }
            } else {
                expandTimer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !hovering {
                        withAnimation { expanded = false }
                        onExpandChange?(false)
                    }
                }
            }
        }
        .onAppear {
            if forceExpanded { expanded = true; onExpandChange?(true) }
        }
    }

    // MARK: - 收起态
    /// 布局：[左翼: 图标+状态灯] [中段: 纯黑与刘海融合] [右翼: 新建按钮]
    private var collapsedView: some View {
        HStack(spacing: 0) {
            // 左翼：Comate 图标 + 状态灯（灯叠在图标右下角）
            ZStack(alignment: .bottomTrailing) {
                ComateLogo(size: 14)  // 从 18 缩小到 14
                Circle()
                    .fill(Color(hex: store.primaryLight.color))
                    .frame(width: 7, height: 7)  // 从 9 缩小到 7
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: store.primaryLight.color).opacity(store.primaryLight == .red ? 0.8 : 0.4),
                            radius: store.primaryLight == .red ? 5 : 3)
            }
            .frame(width: wingWidth, height: notchHeight)

            // 中段：被系统刘海物理遮挡，纯黑自然融合
            Color.black
                .frame(width: notchWidth)

            // 右翼：快速新建任务（仅图标）
            Button(action: { store.launchNewSession() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))  // 从 12 缩小到 11
                    .foregroundColor(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .frame(width: wingWidth, height: notchHeight)
        }
        .frame(width: collapsedTotalWidth, height: notchHeight)
        .background(
            NotchShape(cornerRadius: 14)  // PDF: compact r=14
                .fill(Color.black)
        )
        .clipShape(NotchShape(cornerRadius: 14))
        .contentShape(NotchShape(cornerRadius: 14))
    }

    // MARK: - 展开态

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ComateLogo(size: 14)
                Text("Comate 任务")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
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
                StatusLight(color: store.primaryLight.color, size: 4)
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
        .padding(12)
        .frame(width: expandedWidth, height: expandedHeight)
        .background(
            NotchShape(cornerRadius: 16)  // PDF: expanded r=16
                .fill(Color.black)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        )
        .clipShape(NotchShape(cornerRadius: 16))
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
