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

/// 弧内脉冲的形态（与状态一一对应，见 DESIGN.md §8）
enum LogoPulse: Equatable {
    /// 不脉冲：空闲 / 已完成 / 工作中各有自己的动效
    case none
    /// 双圈错相脉冲：等你确认 —— 要打断你，节奏快
    case double
    /// 单圈慢脉冲：异常 —— 提示但不催
    case single
}

/// 五态动效的状态。映射：灰→空闲、绿→已完成、黄→工作中、
/// 红（等你确认）→等待确认、红（异常）→异常。
enum LogoMotionState: Equatable {
    case idle
    case done
    case working
    case waiting
    case error

    /// 不区分红灯成因时的默认映射（等你确认）。
    init(light: TaskLight) {
        self.init(light: light, redBlinking: true)
    }

    /// 红灯的两种成因走两个状态：`waiting` 要脉冲打断你，`error` 只慢脉冲提示。
    ///
    /// 回归点：早前实现把两者挤在一个 `.waiting` 里，再用 `redBlinking` 布尔量兼作动画开关，
    /// 结果 `error`（`redBlinking == false`）既不脉冲、也完全不播动画（红灯看起来是静止的）。
    init(light: TaskLight, redBlinking: Bool) {
        switch light {
        case .gray:   self = .idle
        case .green:  self = .done
        case .yellow: self = .working
        case .red:    self = redBlinking ? .waiting : .error
        }
    }

    /// 四态色 = `TaskLight`（`#8E8E93 / #34C759 / #FFB800 / #FF3B30`）。
    ///
    /// v3.4（T5 收敛试版）：徽标此前走 demo 调色板
    /// （`#9CA0AA / #31D158 / #FFC928 / #FF6259`），与同一面板里任务行圆点
    /// `StatusLight` 的 `TaskLight` 并存 —— 同屏两组近义色是最容易看出「不精致」的地方。
    /// 现在徽标与任务行圆点取同一支颜色，T5 在「面板内部」这一层先收敛。
    /// 注意：DESIGN.md §2.5 登记的四态 token（`status.*`）仍是 demo 值，用它的是
    /// 关于窗图例卡等界面元素——本次没动，若要连 token 一并改需另开一轮。
    var color: String {
        switch self {
        case .idle:    return TaskLight.gray.color
        case .done:    return TaskLight.green.color
        case .working: return TaskLight.yellow.color
        case .waiting, .error: return TaskLight.red.color
        }
    }

    /// 弧内脉冲形态。两种红共用同一支颜色，只靠脉冲形态与频率区分。
    var pulse: LogoPulse {
        switch self {
        case .idle, .done, .working: return .none
        case .waiting:               return .double
        case .error:                 return .single
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
    /// 外扩脉冲半径。v3.4：82 → 100。82 时 28pt 下脉冲直径只有 5.6→9.5pt，
    /// 配合 8×scale = 0.37pt 的亚像素线宽，肉眼判定为「静止」；
    /// 100 + 线宽半径 10 = 110，仍完全落在底弧内缘 119 之内，不会压到底弧。
    static let waitingWaveRadius: CGFloat = 100
    /// 脉冲圈线宽（独立常量，不再沿用弧内元素的通用 8）。
    /// 这是「等待确认看不见在闪」的真正主因：8 × (28/600) = 0.37pt，栅格化后淡到不可辨。
    /// 20 → 28pt 下 0.93pt、18pt（面板徽标）下 0.60pt。
    static let alertWaveStroke: CGFloat = 20
    static let doneCheckStroke: CGFloat = 30
    static let sparkRadius: CGFloat = 8

    // 时长（秒），与 demo 一一对应
    static let idleBreathDuration: Double = 1.9
    static let idleRingDuration: Double = 4.2
    static let doneCheckDuration: Double = 0.62
    static let doneCheckDelay: Double = 0.15
    static let sparkDuration: Double = 0.5
    static let orbitDuration: Double = 1.15
    static let waitingBobDuration: Double = 1.15
    static let waitingWaveDuration: Double = 1.6
    static let waitingWaveDelay: Double = 0.72
    static let enterDuration: Double = 0.52
    static let colorDuration: Double = 0.5

    // 空闲振幅（DESIGN.md §8 方案 A：28pt 下描边会落到亚像素，必须加大）
    static let idleDotMinScale: Double = 0.55
    static let idleDotMaxScale: Double = 1.18
    static let idleDotMinOpacity: Double = 0.32
    static let idleRingStartScale: Double = 0.62
    static let idleRingEndScale: Double = 1.46
    static let idleRingStartOpacity: Double = 0.46

    // 弧内脉冲：两种红共用尺寸，只有圈数与频率不同
    static let alertWaveStartScale: Double = 0.73
    static let alertWaveEndScale: Double = 1.24
    /// v3.4：峰值透明度 .38 → .50。.38 且在 ease-out 里立刻衰减到 0，
    /// 叠上 0.37pt 线宽后整圈几乎不可见；「等你确认」本就该是五态里最刺眼的一档，
    /// 抬到 .50（高于空闲涟漪的 .46）符合它的打断语义。
    static let alertWaveStartOpacity: Double = 0.50
    /// 异常：单圈慢脉冲，透明度峰值比「等你确认」低一档（提示但不催）
    static let errorWaveDuration: Double = 2.4
    static let errorWavePeakOpacity: Double = 0.28
    /// 竖条：等你确认上下轻浮（v3.4：5 → 18 设计单位；5 在 28pt 下只有 0.23pt，
    /// 与脉冲一同构成「完全静止」的观感）；异常不浮动，改为极缓透明度呼吸
    static let alertBarLift: CGFloat = 18
    static let alertBarDim: Double = 0.72
    static let alertBarBright: Double = 1.0
    static let errorBreathDuration: Double = 1.6
    static let errorBarBright: Double = 0.90

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
    /// 红灯是不是「等你确认」。等你回答（auq）要打断你 → 双圈快脉冲；轮次异常 → 单圈慢脉冲。
    var redBlinking: Bool = true
    var size: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: LogoMotionState { LogoMotionState(light: light, redBlinking: redBlinking) }
    private var color: Color { Color(hex: state.color) }
    private var scale: CGFloat { size / LogoMotionMetrics.design }

    /// 是否播放动效：只跟随系统「减弱动态效果」。
    ///
    /// 回归点：早前这里对 `.waiting` 额外返回 `redBlinking`，于是「异常」红
    /// （`redBlinking == false`）完全不播动画——现在两种红各自有动效，不再有这条例外。
    private var animated: Bool { !reduceMotion }

    /// 动效的启停 key：**必须同时含状态与是否动效**。
    ///
    /// 循环动画只在视图首次出现（`onAppear`）时启动，而视图重建是由 `.id` 触发的。
    /// 回归点：早前只写 `.id(state)`，当任务从「等你确认」变成「异常」（或反过来）时
    /// 状态仍是 `.waiting`、`.id` 不变 → 视图不重建 → 动画既不会启动也不会停止。
    /// 把 `animated` 也写进 key，红闪标志翻转就会重建并重新起播。
    struct MotionKey: Hashable {
        let state: LogoMotionState
        let animated: Bool
    }

    static func motionKey(state: LogoMotionState, animated: Bool) -> MotionKey {
        MotionKey(state: state, animated: animated)
    }

    var body: some View {
        ZStack {
            LogoArcShape()
                .stroke(color.opacity(LogoMotionMetrics.arcOpacity),
                        style: StrokeStyle(lineWidth: LogoMotionMetrics.arcStroke * scale,
                                           lineCap: .butt, lineJoin: .round))
            indicator
                .id(Self.motionKey(state: state, animated: animated))
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
        case .waiting, .error:
            AlertIndicator(scale: scale, color: color, pulse: state.pulse, animated: animated)
        }
    }
}

// MARK: - 各状态弧内指示

/// 空闲：中心柔光点呼吸 + 一圈外扩涟漪。
/// 振幅按 DESIGN.md §8 方案 A 加大（28pt 下描边会落到亚像素，原参数几乎看不出动），
/// 加大后仍为五态中最安静的一档。
private struct IdleIndicator: View {
    let scale: CGFloat
    let color: Color
    /// 注意：`animated` 是父视图 `.id` 的一部分——它一变，本视图会重建、`onAppear` 重跑。
    let animated: Bool

    @State private var breath = false
    @State private var ping = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 8 * scale)
                .frame(width: LogoMotionMetrics.idleRingRadius * 2 * scale,
                       height: LogoMotionMetrics.idleRingRadius * 2 * scale)
                .scaleEffect(ping ? LogoMotionMetrics.idleRingEndScale
                                  : LogoMotionMetrics.idleRingStartScale)
                .opacity(ping ? 0 : LogoMotionMetrics.idleRingStartOpacity)
            Circle()
                .fill(color)
                .frame(width: LogoMotionMetrics.idleDotRadius * 2 * scale,
                       height: LogoMotionMetrics.idleDotRadius * 2 * scale)
                .scaleEffect(breath ? LogoMotionMetrics.idleDotMaxScale
                                    : LogoMotionMetrics.idleDotMinScale)
                .opacity(breath ? 1 : LogoMotionMetrics.idleDotMinOpacity)
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

/// 两种红灯共用的弧内指示（感叹号 + 外扩脉冲）。
///
/// - `.double`（等你确认）：双圈错相脉冲 `1.6s`（半径 `100`、线宽 `20`、峰值透明度 `.50`），
///   竖条上下轻浮 `18 / 1.15s`
/// - `.single`（异常）：单圈慢脉冲 `2.4s`、峰值透明度降到 `.28`，竖条不浮动，改为极缓透明度呼吸
///
/// 两者形状、颜色完全一致，只靠脉冲圈数与频率区分——不需要靠转圈/额外图标。
private struct AlertIndicator: View {
    let scale: CGFloat
    let color: Color
    let pulse: LogoPulse
    /// 注意：`animated` 是父视图 `.id` 的一部分——它一变，本视图会重建、`onAppear` 重跑。
    let animated: Bool

    @State private var pulseOn = false
    @State private var barOn = false

    private var isDouble: Bool { pulse == .double }

    /// 双圈错相 0.72s；单圈只有一个
    private var waves: [Double] {
        isDouble ? [0, LogoMotionMetrics.waitingWaveDelay] : [0]
    }

    private var waveDuration: Double {
        isDouble ? LogoMotionMetrics.waitingWaveDuration : LogoMotionMetrics.errorWaveDuration
    }

    private var wavePeakOpacity: Double {
        isDouble ? LogoMotionMetrics.alertWaveStartOpacity : LogoMotionMetrics.errorWavePeakOpacity
    }

    private var barDuration: Double {
        isDouble ? LogoMotionMetrics.waitingBobDuration : LogoMotionMetrics.errorBreathDuration
    }

    private var barBright: Double {
        isDouble ? LogoMotionMetrics.alertBarBright : LogoMotionMetrics.errorBarBright
    }

    var body: some View {
        ZStack {
            ForEach(Array(waves.indices), id: \.self) { i in
                Circle()
                    .stroke(color, lineWidth: LogoMotionMetrics.alertWaveStroke * scale)
                    .frame(width: LogoMotionMetrics.waitingWaveRadius * 2 * scale,
                           height: LogoMotionMetrics.waitingWaveRadius * 2 * scale)
                    .scaleEffect(pulseOn ? LogoMotionMetrics.alertWaveEndScale
                                         : LogoMotionMetrics.alertWaveStartScale)
                    .opacity(pulseOn ? 0 : wavePeakOpacity)
                    .animation(.easeOut(duration: waveDuration)
                        .delay(waves[i])
                        .repeatForever(autoreverses: false), value: pulseOn)
            }

            // 竖条：demo 的 M 300 248 → 300 320，中心 y=284。异常态不浮动，只呼吸透明度。
            Capsule()
                .fill(color)
                .frame(width: LogoMotionMetrics.waitingBarWidth * scale,
                       height: LogoMotionMetrics.waitingBarLength * scale)
                .offset(y: -16 * scale + (isDouble && barOn
                                          ? -LogoMotionMetrics.alertBarLift * scale : 0))
                .opacity(barOn ? barBright : LogoMotionMetrics.alertBarDim)
                .animation(.easeInOut(duration: barDuration)
                    .repeatForever(autoreverses: true), value: barOn)
            // 圆点：(300,362)，demo 里圆点不动，只有竖条动
            Circle()
                .fill(color)
                .frame(width: LogoMotionMetrics.waitingDotRadius * 2 * scale,
                       height: LogoMotionMetrics.waitingDotRadius * 2 * scale)
                .offset(y: 62 * scale)
        }
        .onAppear {
            guard animated else { return }
            pulseOn = true
            barOn = true
        }
    }
}
