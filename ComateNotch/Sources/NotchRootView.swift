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
    var wingWidth: CGFloat = 36  // 收窄到 36
    var notchHeight: CGFloat
    var expandedWidth: CGFloat = 280  // 收窄到 280
    var expandedHeight: CGFloat = 280  // 新增：展开高度

    private var collapsedTotalWidth: CGFloat { notchWidth + wingWidth * 2 }

    @State private var hovering = false
    @State private var expandTimer: Timer?
    @State private var isAnimating = false  // 动画期间标记，避免刷新干扰
    private let forceExpanded = CommandLine.arguments.contains("--expanded")

    var body: some View {
        let currentWidth = expanded ? expandedWidth : collapsedTotalWidth
        let currentHeight = expanded ? expandedHeight : notchHeight
        let cornerR: CGFloat = 14

        NotchShape(cornerRadius: cornerR)
            .fill(Color.black)
            .frame(width: currentWidth, height: currentHeight)
            // 叠加层：logo + 状态灯（固定位置）
            .overlay(alignment: .topLeading) {
                ComateLogo(size: 18, colorful: expanded)
                    .position(x: wingWidth / 2, y: notchHeight / 2)
                    .overlay(alignment: .topLeading) {
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
                            .position(x: 15, y: 15)
                    }
            }
            // 叠加层：消息中心徽章（右翼）
            .overlay(alignment: .topTrailing) {
                Button(action: { store.openNewTask() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(.trailing, wingWidth / 2 - 2)
                .padding(.top, (notchHeight - 18) / 2)
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            // 叠加层：展开内容
            .overlay {
                expandedContent
                    .opacity(expanded ? 1 : 0)
                    .allowsHitTesting(expanded)
            }
            .animation(.easeInOut(duration: 0.12), value: store.primaryLight)
            .animation(.easeInOut(duration: 0.22), value: expanded)
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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

    // MARK: - 展开内容（始终在视图树中，通过 opacity 显隐）
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {

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
                // 消息数提示
                if store.totalMessageCount > 0 {
                    Text("\(store.totalMessageCount) 条消息")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 12)
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
