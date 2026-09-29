import SwiftUI

// MARK: - 状态动效：logo 与状态灯合一
//
// 来源：外部 demo 的四态动效（C 形弧 + 弧内状态指示），采用其中的「方案 B」参数：
// 底弧压暗到 55%、追逐光轨外扩到 r268 并加粗、弧内标记略放大 —— 这三处只影响
// 18pt 下的可读性，动效曲线 / 时长 / 节奏与 demo 完全一致。
//
// 为什么要压暗底弧：光轨与底弧同色，且 demo 里光轨（r250）正好落在底弧（r185 + 132 描边，
// 覆盖 r119–251）的带宽内 —— 在 demo 的 600pt 预览尺寸下能看出「亮弧在转」，到 HUD 的
// 18pt 就退化成静止圆环（逐帧像素差 0.4–0.8，方案 B 是 2.0–3.6）。
//
// 坐标一律用 demo 的 600 设计空间书写，落地时按 size/600 换算，不整体 scaleEffect：
// 缩放一整个视图层会让 18pt 的小图标栅格化发虚。

/// 四态动效的状态。映射：灰→空闲、绿→已完成、黄→工作中、红→等待确认。
enum LogoMotionState: Equatable {
    case idle
    case done
    case working
    case waiting

    init(light: TaskLight) {
        switch light {
        case .gray:   self = .idle
        case .green:  self = .done
        case .yellow: self = .working
        case .red:    self = .waiting
        }
    }

    /// demo 调色板。客户端原有四色（#8E8E93 / #34C759 / #FFB800 / #FF3B30）暂时让位：
    /// 本次先按 demo 配色看效果，确认后再决定是否统一到既有视觉基线。
    var color: String {
        switch self {
        case .idle:    return "#9CA0AA"
        case .done:    return "#31D158"
        case .working: return "#FFC928"
        case .waiting: return "#FF6259"
        }
    }
}

/// 动效几何常量与纯函数（可脱离界面断言，见 test.sh）。
/// 全部以 demo 的 600 设计空间为单位。
enum LogoMotionMetrics {
    static let design: CGFloat = 600

    // 底弧：demo 的 SVG 路径 M 181 442 A 185 185 0 1 1 419 442
    // 圆心 (300,300)、半径 185；起止角 130° → 410°（y 向下时角度递增 = 屏幕顺时针），
    // 扫过 280°，缺口留在正下方 —— 这正是「C」的开口。
    static let arcStartAngle: Double = 130
    static let arcEndAngle: Double = 410
    static let arcRadius: CGFloat = 185
    static let arcStroke: CGFloat = 132
    /// 方案 B：底弧压暗，让同色光轨能被看见
    static let arcOpacity: Double = 0.55

    /// 追逐光轨半径（方案 B：由 r250 外扩到 r268，脱离底弧带宽）
    static let orbitRadius: CGFloat = 268
    static let orbitLeadWidth: CGFloat = 38
    static let orbitMidWidth: CGFloat = 26
    static let orbitTailWidth: CGFloat = 16
    static let orbitMidOpacity: Double = 0.70
    static let orbitTailOpacity: Double = 0.34

    static var orbitCircumference: CGFloat { 2 * .pi * orbitRadius }

    /// 三段光轨的弧长占比（dash / 周长）。demo 用 r250 的绝对 dash 值，
    /// 外扩半径后必须按周长等比放大，否则同样的 dash 在更大的圆上看起来更短。
    static var leadTrim: (from: CGFloat, to: CGFloat) { (0, 111.5 / orbitCircumference) }
    static var midTrim: (from: CGFloat, to: CGFloat) {
        (92.2 / orbitCircumference, (92.2 + 62.2) / orbitCircumference)
    }
    static var tailTrim: (from: CGFloat, to: CGFloat) {
        (165.1 / orbitCircumference, (165.1 + 30.0) / orbitCircumference)
    }

    // 弧内状态指示
    static let idleDotRadius: CGFloat = 26
    static let idleRingRadius: CGFloat = 42
    static let waitingBarWidth: CGFloat = 30
    static let waitingBarLength: CGFloat = 72
    static let waitingDotRadius: CGFloat = 16
    static let waitingWaveRadius: CGFloat = 82
    static let doneCheckStroke: CGFloat = 30
    static let sparkRadius: CGFloat = 8

    // 时长（秒），与 demo 一一对应
    static let idleBreathDuration: Double = 2.5
    static let idleRingDuration: Double = 2.5
    static let doneCheckDuration: Double = 0.62
    static let doneCheckDelay: Double = 0.15
    static let sparkDuration: Double = 0.5
    static let orbitDuration: Double = 1.15
    static let waitingBobDuration: Double = 1.15
    static let waitingWaveDuration: Double = 1.6
    static let waitingWaveDelay: Double = 0.72
    static let enterDuration: Double = 0.52
    static let colorDuration: Double = 0.5

    /// 780° 多的弧长（用于断言圆弧确实是「长弧」而不是短弧）
    static var arcSweep: Double { arcEndAngle - arcStartAngle }
}

// MARK: - 形状

/// 底弧：固定 C 形（不随状态变化，只换色与透明度）
struct LogoArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / LogoMotionMetrics.design
        let c = CGPoint(x: 300 * s, y: 300 * s)
        var p = Path()
        p.addArc(center: c,
                 radius: LogoMotionMetrics.arcRadius * s,
                 startAngle: .degrees(LogoMotionMetrics.arcStartAngle),
                 endAngle: .degrees(LogoMotionMetrics.arcEndAngle),
                 clockwise: false)
        return p
    }
}

/// 对勾路径（demo: M 245 304 L 284 343 L 365 255）
struct LogoCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / LogoMotionMetrics.design
        var p = Path()
        p.move(to: CGPoint(x: 245 * s, y: 304 * s))
        p.addLine(to: CGPoint(x: 284 * s, y: 343 * s))
        p.addLine(to: CGPoint(x: 365 * s, y: 255 * s))
        return p
    }
}

// MARK: - 主视图

/// 悬浮窗 / 刘海左侧图标：logo（C 形弧）与状态灯合一。
struct LogoMotionBadge: View {
    var light: TaskLight
    /// 红灯是否脉冲。等你回答（auq）要打断你 → 脉冲；轮次异常 → 常亮，不闪。
    var redBlinking: Bool = true
    var size: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: LogoMotionState { LogoMotionState(light: light) }
    private var color: Color { Color(hex: state.color) }
    private var scale: CGFloat { size / LogoMotionMetrics.design }

    /// 是否播放动效：跟随系统「减弱动态效果」；红灯常亮时也不播放
    private var animated: Bool {
        if reduceMotion { return false }
        if state == .waiting { return redBlinking }
        return true
    }

    var body: some View {
        ZStack {
            LogoArcShape()
                .stroke(color.opacity(LogoMotionMetrics.arcOpacity),
                        style: StrokeStyle(lineWidth: LogoMotionMetrics.arcStroke * scale,
                                           lineCap: .butt, lineJoin: .round))
            indicator
                .id(state)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92)),
                    removal: .opacity.combined(with: .scale(scale: 0.92))))
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: LogoMotionMetrics.enterDuration), value: state)
        .animation(.easeInOut(duration: LogoMotionMetrics.colorDuration), value: state)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .idle:    IdleIndicator(scale: scale, color: color, animated: animated)
        case .done:    DoneIndicator(scale: scale, color: color, animated: animated)
        case .working: WorkingIndicator(scale: scale, color: color, animated: animated)
        case .waiting: WaitingIndicator(scale: scale, color: color, animated: animated)
        }
    }
}

// MARK: - 各状态弧内指示

/// 空闲：中心柔光点呼吸 + 一圈外扩涟漪
private struct IdleIndicator: View {
    let scale: CGFloat
    let color: Color
    let animated: Bool

    @State private var breath = false
    @State private var ping = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 8 * scale)
                .frame(width: LogoMotionMetrics.idleRingRadius * 2 * scale,
                       height: LogoMotionMetrics.idleRingRadius * 2 * scale)
                .scaleEffect(ping ? 1.35 : 0.72)
                .opacity(ping ? 0 : 0.34)
            Circle()
                .fill(color)
                .frame(width: LogoMotionMetrics.idleDotRadius * 2 * scale,
                       height: LogoMotionMetrics.idleDotRadius * 2 * scale)
                .scaleEffect(breath ? 1 : 0.78)
                .opacity(breath ? 1 : 0.48)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: LogoMotionMetrics.idleBreathDuration)
                .repeatForever(autoreverses: true)) { breath = true }
            withAnimation(.easeOut(duration: LogoMotionMetrics.idleRingDuration)
                .repeatForever(autoreverses: false)) { ping = true }
        }
    }
}

/// 已完成：对勾自左向右绘制 + 三颗迸发星点
private struct DoneIndicator: View {
    let scale: CGFloat
    let color: Color
    let animated: Bool

    @State private var drawn = false

    private var sparks: [(x: CGFloat, y: CGFloat, r: CGFloat, delay: Double)] {
        [(389, 230, 8, 0.58), (218, 256, 6, 0.68), (370, 374, 5, 0.74)]
    }

    var body: some View {
        ZStack {
            LogoCheckShape()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(color, style: StrokeStyle(
                    lineWidth: LogoMotionMetrics.doneCheckStroke * scale,
                    lineCap: .round, lineJoin: .round))
                .animation(.easeOut(duration: LogoMotionMetrics.doneCheckDuration)
                    .delay(LogoMotionMetrics.doneCheckDelay), value: drawn)

            ForEach(sparks.indices, id: \.self) { i in
                let spark = sparks[i]
                Circle()
                    .fill(color)
                    .frame(width: spark.r * 2 * scale, height: spark.r * 2 * scale)
                    .offset(x: (spark.x - 300) * scale, y: (spark.y - 300) * scale)
                    .scaleEffect(drawn ? 1 : 0.2)
                    .opacity(drawn ? 0.85 : 0)
                    .animation(.easeOut(duration: LogoMotionMetrics.sparkDuration)
                        .delay(spark.delay), value: drawn)
            }
        }
        .onAppear { drawn = true }
    }
}

/// 工作中：三段光轨沿圆环追逐（头亮、中弱、尾淡）
private struct WorkingIndicator: View {
    let scale: CGFloat
    let color: Color
    let animated: Bool

    @State private var spin = false

    private func orbit(width: CGFloat, opacity: Double, trim: (from: CGFloat, to: CGFloat)) -> some View {
        Circle()
            .trim(from: trim.from, to: trim.to)
            .stroke(color.opacity(opacity),
                    style: StrokeStyle(lineWidth: width * scale, lineCap: .round))
            .frame(width: LogoMotionMetrics.orbitRadius * 2 * scale,
                   height: LogoMotionMetrics.orbitRadius * 2 * scale)
    }

    var body: some View {
        ZStack {
            orbit(width: LogoMotionMetrics.orbitTailWidth,
                  opacity: LogoMotionMetrics.orbitTailOpacity,
                  trim: LogoMotionMetrics.tailTrim)
            orbit(width: LogoMotionMetrics.orbitMidWidth,
                  opacity: LogoMotionMetrics.orbitMidOpacity,
                  trim: LogoMotionMetrics.midTrim)
            orbit(width: LogoMotionMetrics.orbitLeadWidth,
                  opacity: 1,
                  trim: LogoMotionMetrics.leadTrim)
                .shadow(color: color.opacity(0.55), radius: 14 * scale)
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .animation(.linear(duration: LogoMotionMetrics.orbitDuration)
            .repeatForever(autoreverses: false), value: spin)
        .onAppear { if animated { spin = true } }
    }
}

/// 等待确认：感叹号（竖条 + 圆点）上下轻浮 + 两圈外扩脉冲
private struct WaitingIndicator: View {
    let scale: CGFloat
    let color: Color
    let animated: Bool

    @State private var bob = false
    @State private var ping = false

    private var waves: [Double] { [0, LogoMotionMetrics.waitingWaveDelay] }

    var body: some View {
        ZStack {
            ForEach(Array(waves.indices), id: \.self) { i in
                Circle()
                    .stroke(color, lineWidth: 8 * scale)
                    .frame(width: LogoMotionMetrics.waitingWaveRadius * 2 * scale,
                           height: LogoMotionMetrics.waitingWaveRadius * 2 * scale)
                    .scaleEffect(ping ? 1.24 : 0.73)
                    .opacity(ping ? 0 : 0.38)
                    .animation(.easeOut(duration: LogoMotionMetrics.waitingWaveDuration)
                        .delay(waves[i])
                        .repeatForever(autoreverses: false), value: ping)
            }

            // 竖条：demo 的 M 300 248 → 300 320，中心 y=284
            Capsule()
                .fill(color)
                .frame(width: LogoMotionMetrics.waitingBarWidth * scale,
                       height: LogoMotionMetrics.waitingBarLength * scale)
                .offset(y: -16 * scale + (bob ? -5 * scale : 0))
                .opacity(bob ? 1 : 0.72)
            // 圆点：(300,362)，demo 里圆点不浮动，只有竖条轻浮
            Circle()
                .fill(color)
                .frame(width: LogoMotionMetrics.waitingDotRadius * 2 * scale,
                       height: LogoMotionMetrics.waitingDotRadius * 2 * scale)
                .offset(y: 62 * scale)
        }
        .animation(.easeInOut(duration: LogoMotionMetrics.waitingBobDuration)
            .repeatForever(autoreverses: true), value: bob)
        .onAppear {
            guard animated else { return }
            bob = true
            ping = true
        }
    }
}
