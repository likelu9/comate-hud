import AppKit
import SwiftUI

// MARK: - 任务行列表（刘海模式 / 悬浮模式共用）

struct HUDTaskRows: View {
    @ObservedObject var store: ComateStore
    var spacing: CGFloat = 3

    /// 任务行内边距。12 太松散（行间视觉间隙 28pt），收敛到 8：
    /// 行高 50 = 内容 34 + 上下各 8，卡与卡之间留 8 + 2(行距) + 8 = 18pt
    static let rowPadV: CGFloat = 8
    static let rowPadH: CGFloat = 10

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(store.recentTasks.prefix(store.recentTaskLimit)) { task in
                ComateTaskRow(task: task) {
                    store.openSession(task)
                }
            }
        }
    }
}

// MARK: - 页脚：额度周期切换 + 消息铃铛 + 设置（刘海模式 / 悬浮模式共用）

/// 页脚几何（DESIGN.md §7.1 `footer-quota`）。两种显示模式共用一套值，不再分形态：
///
/// ```
/// ┌ 第 1 行 14 ─────────────────────────────────────────────┐
/// │ [日|月] 已用 x / y 点              │  🔔   ⚙️            │
/// ├ 行距 4 ────────────────────────────────────────────────┤
/// │ ▓▓▓▓▓▓░░░░░░░░░░░░  62%   ← 只在左侧额度区内收口          │
/// └ 上下内边距 6，总高 34 ─────────────────────────────────┘
/// ```
///
/// 两个硬约束：
/// 1. 第 2 行的进度条 + 百分比宽度 = 左侧额度区宽（内容宽 − 图标簇 − 最小间距）。
///    早期把进度条按整行铺开，固定 36pt 右对齐的百分比正好落在齿轮正下方，
///    读起来像齿轮的附属读数；额度属左侧额度区，必须在竖线左侧结束（用户反馈 ①）。
/// 2. 右侧图标簇固定尺寸（`.fixedSize()` + `layoutPriority`），额度读数再长也挤不动它。
///
/// 数值来源：`docs/designs/references/panel-main.html` 的 `footer-quota`
/// （分隔线 x=179 / 铃铛 x=185 / 齿轮 x=219 / 百分比位 36pt）。
/// 故意不设 `private`：这张表是设计稿落地值的唯一来源，需要能被 `test.sh` 直接断言，
/// 否则「改了一处漏了另一处」只能靠肉眼发现（与 `NotchLayout` / `FloatingMetrics` 同一处理）。
struct FooterMetrics {
    /// 两行额度块的高（第 1 行 14 + 行距 4 + 第 2 行 14）
    var rowsHeight: CGFloat { rowHeight * 2 + rowSpacing }
    /// 页脚总高（6 + max(两行额度块 32, 图标簇 22) + 6 = 44）
    var height: CGFloat { padV * 2 + max(rowsHeight, hitHeight) }
    var padV: CGFloat { 6 }
    /// 第 1 行行高
    var rowHeight: CGFloat { 14 }
    /// 两行之间的行距
    var rowSpacing: CGFloat { 4 }
    /// 行内元素之间的间距
    var gap: CGFloat { 6 }
    /// 齿轮热区（设计稿 32×22）。热区高于行高是有意的：向上下各溢出 4pt，
    /// 但那一列上下都没有别的可点元素，不会误触
    var hitWidth: CGFloat { 32 }
    var hitHeight: CGFloat { 22 }
    /// 铃铛热区比齿轮窄（设计稿铃铛 x=185、齿轮 x=219，两者间距 2）
    var bellHitWidth: CGFloat { 22 }
    var clusterSpacing: CGFloat { 2 }
    var corner: CGFloat { 4 }
    /// 额度区与消息·设置区之间的分区竖线
    var dividerWidth: CGFloat { 1 }
    /// 竖线高（设计稿）
    var dividerHeight: CGFloat { 16 }
    /// 图标簇的左内边距：竖线画在这段留白里，不吃额外宽度
    var clusterPadding: CGFloat { 6 }
    /// 额度区与图标簇之间至少留的间距
    var quotaGap: CGFloat { 8 }

    var quotaFont: CGFloat { 10 }
    var iconFont: CGFloat { 10.5 }
    var countFont: CGFloat { 10 }
    var percentFont: CGFloat { 10 }
    var segFont: CGFloat { 9.5 }
    var segWidth: CGFloat { 17 }
    var segHeight: CGFloat { 14 }
    var segCorner: CGFloat { 4 }

    /// 进度条高 4pt（设计稿）
    var barHeight: CGFloat { 4 }
    /// 百分比读数占位：固定宽 + 右对齐，62% / 61.7% / 100% 都不会推挤进度条
    var percentWidth: CGFloat { 36 }

    /// 右侧图标簇总宽（竖线留白 + 铃铛 + 间距 + 齿轮）
    var clusterWidth: CGFloat { clusterPadding + bellHitWidth + clusterSpacing + hitWidth }

    /// 左侧额度区宽 = 内容宽 − 图标簇 − 最小间距（内容宽 252 时 = 182，
    /// 与设计稿的分隔线 x=179 同量级）。
    /// 仅作几何契约（视图内由 HStack 均分屏幕实现），用于断言与调试
    func quotaWidth(contentWidth: CGFloat) -> CGFloat {
        max(0, contentWidth - clusterWidth - quotaGap)
    }
}

struct HUDUsageFooter: View {
    @ObservedObject var store: ComateStore
    /// 面板内容宽（面板宽 − 左右内边距）。两侧布局由 HStack 自己均分（额度块吃满剩余宽），
    /// 这里仅作为几何契约保留给断言与调试
    var contentWidth: CGFloat
    /// 设置按钮动作。必填而非可选：设置是功能而不是装饰，
    /// 两种显示模式都必须提供，避免再出现「某个模式没有设置按钮」
    let onSettings: () -> Void
    /// 登录 / 重新登录。未登录与登录失效时，额度位会变成指向它的按钮
    let onLogin: () -> Void

    @State private var usageToggleHovered = false
    @State private var loginHovered = false
    @State private var bellHovered = false
    @State private var settingsHovered = false
    @State private var bellRotate = false

    private var m: FooterMetrics { FooterMetrics() }

    var body: some View {
        HStack(spacing: m.gap) {
            quotaBlock
            iconCluster
        }
        .padding(.vertical, m.padV)
    }

    /// 左侧额度块：两行等宽、左缘同起右缘同止（用户反馈 ⑤「两端对齐」）。
    /// 上=周期胶囊 + 额度读数（两端推开），下=进度条 + 百分比（条填充剩余空白）。
    /// 整块 `.frame(maxWidth: .infinity)` 吃满图标簇之外的宽度 —— 用量不再靠左缩成一小截
    private var quotaBlock: some View {
        VStack(spacing: m.rowSpacing) {
            usageSlot
                .frame(height: m.rowHeight)
            HStack(spacing: m.gap) {
                progressBar
                percentLabel
            }
            .frame(height: m.rowHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 额度位：未登录 / 登录失效时整体换成登录引导，其余情况是「胶囊 + 读数（+ 内联进度条）」
    @ViewBuilder
    private var usageSlot: some View {
        if store.needsLogin {
            loginPrompt
        } else {
            usageToggle
        }
    }

    /// 右侧图标簇：铃铛 + 齿轮，左缘一条 1pt 竖线把「额度区」与「消息·设置区」分开。
    /// 竖线画在簇的左内边距里（不吃额外宽度）；整簇固定尺寸，读数再长也不会挤动它。
    /// 排布统一取刘海模式（用户反馈：两种显示模式共用同一版式）
    private var iconCluster: some View {
        HStack(spacing: m.clusterSpacing) {
            bellButton
            settingsButton
        }
        .padding(.leading, m.clusterPadding)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(HUDDesign.lineDivider)
                .frame(width: m.dividerWidth, height: m.dividerHeight)
        }
        .fixedSize()
        .layoutPriority(1)
    }

    /// 消息中心入口。未读为 0 时仍然显示（页脚结构固定①→④），只是不带角标——
    /// 否则齿轮会随着「有没有未读」左右横跳。
    private var bellButton: some View {
        Button(action: { store.openMessageCenter() }) {
            HStack(spacing: 3) {
                if store.isOpeningMessageCenter {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: m.iconFont))
                        .rotationEffect(.degrees(bellRotate ? 360 : 0))
                        .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: bellRotate)
                        .onAppear { bellRotate = true }
                } else {
                    Image(systemName: "bell.fill")
                        .font(.system(size: m.iconFont))
                        .scaleEffect(bellHovered ? 1.15 : 1.0)
                    if store.totalMessageCount > 0 {
                        Text("\(store.totalMessageCount)")
                            .font(.system(size: m.countFont, weight: .semibold, design: .rounded))
                    }
                }
            }
            .foregroundStyle(.white.opacity(bellHovered || store.isOpeningMessageCenter ? 0.9 : 0.55))
            .frame(width: m.bellHitWidth, height: m.hitHeight)
            .contentShape(RoundedRectangle(cornerRadius: m.corner))
            .background(
                (bellHovered ? HUDDesign.hit : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: m.corner))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            bellHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: bellHovered)
        .help(store.isOpeningMessageCenter ? "正在打开消息中心…" : "打开消息中心")
    }

    /// 设置入口：直接打开设置窗口（动作由调用方给，当前两种模式下都是开窗）。
    /// 有新版时齿轮右上角带 5pt 红点，点进来后会落在「通用」页继续引导（见 AppDelegate）
    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: m.iconFont))
                .foregroundStyle(.white.opacity(settingsHovered ? 0.9 : 0.55))
                // 有新版可用：贴图标右上角亮红点（挂在图标上而非热区，避免小按钮里红点飘到远端）
                .overlay(alignment: .topTrailing) {
                    if store.showsUpdateDot {
                        UpdateDotBadge()
                            .offset(x: 3, y: -3)
                    }
                }
                .frame(width: m.hitWidth, height: m.hitHeight)
                .contentShape(RoundedRectangle(cornerRadius: m.corner))
                .background(
                    (settingsHovered ? HUDDesign.hit : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: m.corner))
                )
        }
        .buttonStyle(.plain)
        .onHover { h in
            settingsHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: settingsHovered)
        .help(store.showsUpdateDot
              ? "设置（检测到新版 \(store.availableUpdate ?? "")）"
              : "设置")
    }

    /// 额度进度条：吃满第 2 行里除百分比外的剩余宽度（整行宽度已按额度区收口）。
    /// 额度未知（无数据 / 未登录）时轨道退回中性白 10%，不用品牌绿——
    /// 绿轨道会被读成「额度存在」，而此刻其实一个数也没读到。
    private var progressBar: some View {
        GeometryReader { g in
            let known = store.activeUsageLimit != nil
            let ratio = min(max(store.usagePercent, 0), 100) / 100
            ZStack(alignment: .leading) {
                Capsule().fill(known ? Color.clear : HUDDesign.track)
                if known {
                    Capsule().fill(HUDDesign.accentTrack)
                    Capsule().fill(HUDDesign.accent)
                        .frame(width: g.size.width * ratio)
                }
            }
        }
        .frame(height: m.barHeight)
    }

    /// 百分比读数：固定 36pt 宽 + 右对齐
    private var percentLabel: some View {
        Text(store.usagePercentLabel)
            .font(.system(size: m.percentFont, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(store.isUsageLow
                             ? Color(hex: TaskLight.red.color)
                             : HUDDesign.textSecondary)
            .frame(width: m.percentWidth, alignment: .trailing)
    }

    /// 额度读数「已用 x / y 点」。放不下时先降级去掉「已用」二字（防跑版第二档）。
    private var quotaReadout: some View {
        let readout = store.usageFooterReadout
        let label = HUDDesign.textSecondary
        let value = store.isUsageLow ? Color(hex: TaskLight.red.color) : HUDDesign.textStrong
        return (
            Text(store.usageReadoutNeedsTrim ? "" : "已用 ").foregroundColor(label)
            + Text(readout.used).foregroundColor(value)
            + Text(" / ").foregroundColor(label)
            + Text(readout.total).foregroundColor(value)
            + Text(" 点").foregroundColor(label)
        )
        .font(.system(size: m.quotaFont, weight: .medium, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        // 兜底：真落到三档都放不下的极端值，宁可轻微缩字也不截断、不压到右边按钮上
        .minimumScaleFactor(0.85)
    }

    /// 额度周期切换：胶囊 + 读数（+ 内联进度条）一起点，热区仅覆盖内容本身（不占满整行）
    private var usageToggle: some View {
        Button(action: { store.toggleUsagePeriod() }) {
            // 两端对齐：胶囊贴左缘、读数贴右缘，与下一行的进度条/百分比同起同止
            HStack(spacing: m.gap) {
                usagePeriodIndicator
                Spacer(minLength: m.gap)
                quotaReadout
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: m.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: m.corner))
            .background(
                RoundedRectangle(cornerRadius: m.corner)
                    .fill(usageToggleHovered ? HUDDesign.hit : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            usageToggleHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: usageToggleHovered)
        .help(store.usageLimitDetail)
    }

    /// 未登录 / 登录失效的登录引导。
    /// 换成品牌绿实底 + 深墨字（绿是交互色、这里是唯一的行动号召），
    /// 用它整体替掉额度位——「得先去登录」必须比一个「—」显眼。
    /// 失效与未登录靠文案区分，不靠颜色：额度位只允许出现品牌绿一支饱和色。
    private var loginPrompt: some View {
        Button(action: onLogin) {
            HStack(spacing: 5) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: m.iconFont))
                Text(store.loginPromptLabel)
                    .font(.system(size: m.quotaFont + 0.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(HUDDesign.ink)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(HUDDesign.accent.opacity(loginHovered ? 0.88 : 1))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            loginHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: loginHovered)
        .help(store.usageLimitDetail)
    }

    /// 额度周期指示：双段胶囊（日 | 月），高亮当前周期。纯视觉，点击由外层按钮接管。
    /// 选中段是品牌绿实底，文字必须用深墨 #0F0F11：白字压在品牌绿上只有 ≈1.9:1，读不出来。
    private var usagePeriodIndicator: some View {
        HStack(spacing: 0) {
            ForEach(UsageAPI.Period.allCases, id: \.self) { period in
                let isActive = store.usagePeriod == period
                Text(period.shortLabel)
                    .font(.system(size: m.segFont, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive
                                     ? HUDDesign.ink
                                     : HUDDesign.textTertiary)
                    .frame(width: m.segWidth, height: m.segHeight)
                    .background(
                        RoundedRectangle(cornerRadius: m.segCorner)
                            .fill(isActive ? HUDDesign.accent : Color.clear)
                    )
            }
        }
        .padding(1)
        .background(RoundedRectangle(cornerRadius: m.segCorner + 1).fill(HUDDesign.track))
    }
}

// MARK: - 跨面共用的小件

/// 更新红点徽标（§2.5 `dot.update`：5pt 圆点 + 1pt 分离环）。
/// 齿轮右上角 / 设置窗侧栏「通用」项 / 通用页更新行三处共用同一枚，不各画一遍。
struct UpdateDotBadge: View {
    var size: CGFloat = 5

    var body: some View {
        Circle()
            .fill(HUDDesign.dotUpdate)
            .frame(width: size, height: size)
            .overlay(
                Circle().strokeBorder(HUDDesign.dotUpdateRing, lineWidth: 1)
                    .frame(width: size + 2, height: size + 2)
            )
    }
}

/// 对外链接的唯一来源（设置窗关于页共用）
enum HUDLinks {
    static let website = "https://comate.wpsgo.com/s/HyDSehobOTHX/"
}

/// 跨面共用的设计 token（DESIGN.md §2 的落地值）。值只在这里写一次：
/// 面板 / 页脚 / 设置窗 / 更新窗都从这里取，免得各写一遍 `#00D4AA` 之后改一处漏一处。
/// 布局类常量（窗口尺寸 / 内边距 / 行高）仍各自归各自的 Design 枚举。
///
/// 字号（§2.8）/ 间距（§2.7）只收「多面共用」的那几档；单面专属的行高与内边距
/// 留在各自的 Design 里，避免这张表变成没人看得懂的常量堆。
enum HUDDesign {
    // MARK: 交互主色（§3：品牌绿 #00D4AA 取代 KD 蓝，全链路唯一主色）
    static let accent = Color(hex: "#00D4AA")
    static let accentHover = Color(hex: "#22E0BB")
    static let accentPressed = Color(hex: "#00A98A")
    static let accentDisabled = Color(hex: "#00D4AA").opacity(0.40)
    /// 选中行底 / 激活态底 / 软强调
    static let accentSoft = Color(hex: "#00D4AA").opacity(0.16)
    /// 进度条已填充段
    static let accentTrack = Color(hex: "#00D4AA").opacity(0.22)
    /// 绿底上的文字一律深墨（白字压绿的对比度只有 ≈1.9:1）
    static let ink = Color(hex: "#0F0F11")
    static let accentOn = ink

    // MARK: 表面层次（§2.1，3 档主结构 + 派生）
    /// 面板底：主 HUD 面板、设置窗口、更新窗
    static let panel = Color(hex: "#0F0F11")
    /// 刘海收起条底（与硬件开孔无缝，不用 panel）
    static let bar = Color.black
    /// 悬浮层：次级控件底、设置导航底、面板内浮起卡片
    static let raised = Color.white.opacity(0.06)
    /// 卡面：图例卡、系统要求块、更新说明区
    static let card = Color.white.opacity(0.045)
    static let row = Color.white.opacity(0.04)
    static let rowHover = Color.white.opacity(0.10)
    static let rowPressed = Color.white.opacity(0.14)
    /// 图标按钮悬停命中底
    static let hit = Color.white.opacity(0.12)
    /// 周期胶囊轨道底
    static let track = Color.white.opacity(0.10)
    static let skeleton = Color.white.opacity(0.06)

    // MARK: 文字灰度阶梯（§2.2）
    static let textPrimary = Color(hex: "#F5F5F5")
    static let textSecondary = Color(hex: "#F5F5F5").opacity(0.72)
    static let textTertiary = Color(hex: "#F5F5F5").opacity(0.55)
    static let textQuaternary = Color(hex: "#F5F5F5").opacity(0.46)
    static let textDisabled = Color(hex: "#F5F5F5").opacity(0.30)
    /// 脚注 / 读数里的加粗关键值
    static let textStrong = Color(hex: "#F5F5F5").opacity(0.92)

    // MARK: 描边与焦点（§2.3）
    static let linePanel = Color.white.opacity(0.12)
    static let lineCard = Color.white.opacity(0.07)
    static let lineDivider = Color.white.opacity(0.08)
    static let lineDividerStrong = Color.white.opacity(0.14)
    /// 键盘焦点环
    static let focus = accent

    // MARK: 四态语义色（§2.5，只表状态，不得当装饰色用）
    static let idle = Color(hex: "#9CA0AA")
    static let working = Color(hex: "#FFC928")
    static let waiting = Color(hex: "#FF6259")
    static let done = Color(hex: "#31D158")
    static let idleSoft = Color(hex: "#9CA0AA").opacity(0.14)
    static let workingSoft = Color(hex: "#FFC928").opacity(0.14)
    static let waitingSoft = Color(hex: "#FF6259").opacity(0.14)
    static let doneSoft = Color(hex: "#31D158").opacity(0.14)

    // MARK: 更新红点（§2.5 dot.update：5pt 徽标 + 1pt 分离环，压在任何底上都不糊）
    static let dotUpdate = Color(hex: "#FF4D4F")
    static let dotUpdateRing = Color.black.opacity(0.40)

    // MARK: 圆角（§2.6）
    static let radiusSmall: CGFloat = 4
    static let radiusMiddle: CGFloat = 6
    static let radiusLarge: CGFloat = 8
    static let radiusWindow: CGFloat = 12
    static let radiusCard: CGFloat = 14
    static let radiusPanel: CGFloat = 16

    // MARK: 字号（§2.8，只收跨面共用档）
    static let fontH1: CGFloat = 13
    static let fontBody: CGFloat = 12
    static let fontBtn: CGFloat = 12.5
    static let fontLabel: CGFloat = 11
    static let fontMini: CGFloat = 10.5
    static let fontMeta: CGFloat = 9
}

