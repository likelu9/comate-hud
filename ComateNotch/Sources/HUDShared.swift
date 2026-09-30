import AppKit
import SwiftUI

// MARK: - 任务行列表（刘海模式 / 悬浮模式共用）

struct HUDTaskRows: View {
    @ObservedObject var store: ComateStore
    var spacing: CGFloat = 3

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

/// 页脚形态。两种显示模式共用这一个组件，只是排布不同：
/// - `regular`：悬浮面板。两行结构 —— 第 1 行 额度读数 │ 消息·设置；第 2 行 进度条 + 百分比（总高 34pt）
/// - `compact`：刘海展开面板。单行 —— 额度读数里带一条 30×3 的内联进度条（总高 20pt）
///
/// 为什么要分两种：悬浮面板下方空间宽裕，进度条独占一行才看得清；
/// 刘海展开面板的宽度被硬件开孔压到 281pt，只能把进度条压进读数行。
enum HUDUsageFooterStyle {
    case regular
    case compact
}

/// 页脚两种形态的尺寸表。集中一份，避免「改了大面板漏了小面板」。
private struct FooterMetrics {
    let style: HUDUsageFooterStyle

    /// 组件总高（regular 实测 6 + 14 + 4 + 4 + 6 = 34）
    var height: CGFloat { style == .regular ? 34 : 20 }
    /// 单行（compact）/ 第 1 行（regular）的行高
    var rowHeight: CGFloat { style == .regular ? 14 : 20 }
    /// 两行之间的行距（仅 regular 有意义）
    var rowSpacing: CGFloat { 4 }
    /// 行内元素之间的间距
    var gap: CGFloat { 6 }
    /// 额度组水平内边距：compact 留出竖线呼吸位后压到 4
    var quotaPadding: CGFloat { style == .regular ? 0 : 4 }
    /// 右侧图标热区
    var hitWidth: CGFloat { style == .regular ? 32 : 30 }
    var hitHeight: CGFloat { style == .regular ? 22 : 20 }
    var corner: CGFloat { style == .regular ? 4 : 5 }
    /// 额度区与消息·设置区之间的分区竖线
    var dividerWidth: CGFloat { 1 }
    var dividerHeight: CGFloat { style == .regular ? 16 : 12 }
    /// 图标簇的左内边距：竖线画在这段留白里，不吃额外宽度
    var clusterPadding: CGFloat { 6 }

    var quotaFont: CGFloat { style == .regular ? 10 : 9 }
    var iconFont: CGFloat { style == .regular ? 10.5 : 9 }
    var countFont: CGFloat { style == .regular ? 10 : 9 }
    var percentFont: CGFloat { 10 }
    var segFont: CGFloat { style == .regular ? 9.5 : 8 }
    var segWidth: CGFloat { style == .regular ? 17 : 13 }
    var segHeight: CGFloat { style == .regular ? 14 : 11 }
    var segCorner: CGFloat { style == .regular ? 4 : 3.5 }

    /// 进度条：regular 独占一行、吃满剩余宽度；compact 是读数里的固定宽细线
    var inlineBarWidth: CGFloat? { style == .regular ? nil : 30 }
    var barHeight: CGFloat { style == .regular ? 4 : 3 }
    /// 百分比读数占位：固定宽 + 右对齐，62% / 61.7% / 100% 都不会推挤进度条
    var percentWidth: CGFloat { 36 }
}

struct HUDUsageFooter: View {
    @ObservedObject var store: ComateStore
    /// 排布形态：悬浮面板两行（regular）/ 刘海展开面板单行（compact）
    var style: HUDUsageFooterStyle = .regular
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

    private var m: FooterMetrics { FooterMetrics(style: style) }

    var body: some View {
        if style == .regular { regularBody } else { compactBody }
    }

    /// 悬浮面板：两行结构
    /// 第 1 行 = 周期胶囊 + 额度读数 │ 1pt 竖分隔线 │ 铃铛 + 齿轮
    /// 第 2 行 = 进度条（吃满剩余宽）+ 固定宽百分比
    ///
    /// 两区互不重叠是硬规则：图标簇 `.fixedSize()` 且带 `layoutPriority`，
    /// 左端读数再长也只会在自己的格子里被压缩，永远不会盖到按钮上（用户反馈 ③）。
    private var regularBody: some View {
        VStack(spacing: m.rowSpacing) {
            HStack(spacing: m.gap) {
                usageSlot
                Spacer(minLength: m.gap)
                iconCluster
            }
            .frame(height: m.rowHeight)
            HStack(spacing: m.gap) {
                progressBar
                percentLabel
            }
            .frame(height: m.barHeight)
        }
        .padding(.vertical, 6)
    }

    /// 刘海展开面板：单行（额度读数里带内联进度条）
    private var compactBody: some View {
        HStack(spacing: m.gap) {
            usageSlot
            Spacer(minLength: m.gap)
            iconCluster
        }
        .frame(height: m.height)
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
    private var iconCluster: some View {
        HStack(spacing: 2) {
            bellButton
            settingsButton
        }
        .padding(.leading, m.clusterPadding)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
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
            .frame(width: m.hitWidth, height: m.hitHeight)
            .contentShape(RoundedRectangle(cornerRadius: m.corner))
            .background(
                Color.white.opacity(bellHovered ? 0.12 : 0)
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

    /// 设置：等同右键，弹出与右键一致的菜单（两种模式都有）
    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: m.iconFont))
                .foregroundStyle(.white.opacity(settingsHovered ? 0.9 : 0.55))
                // 有新版可用：贴图标右上角亮红点（挂在图标上而非热区，避免小按钮里红点飘到远端）
                .overlay(alignment: .topTrailing) {
                    if store.showsUpdateDot {
                        Circle()
                            .fill(UpdateDot.color)
                            .frame(width: 5, height: 5)
                            .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 0.5))
                            .offset(x: 3, y: -3)
                    }
                }
                .frame(width: m.hitWidth, height: m.hitHeight)
                .contentShape(RoundedRectangle(cornerRadius: m.corner))
                .background(
                    Color.white.opacity(settingsHovered ? 0.12 : 0)
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
              : "设置（等同右键菜单）")
    }

    /// 额度进度条。regular 吃满第 2 行剩余宽度；compact 是读数里的固定 30pt 细线。
    /// 额度未知（无数据 / 未登录）时轨道退回中性白 10%，不用品牌绿——
    /// 绿轨道会被读成「额度存在」，而此刻其实一个数也没读到。
    private var progressBar: some View {
        GeometryReader { g in
            let known = store.activeUsageLimit != nil
            let ratio = min(max(store.usagePercent, 0), 100) / 100
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(known ? 0 : 0.10))
                if known {
                    Capsule().fill(Color(hex: "#00D4AA").opacity(0.22))
                    Capsule().fill(Color(hex: "#00D4AA"))
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
                             : Color.white.opacity(0.72))
            .frame(width: m.percentWidth, alignment: .trailing)
    }

    /// 额度读数「已用 x / y 点」。放不下时先降级去掉「已用」二字（防跑版第二档）。
    private var quotaReadout: some View {
        let readout = store.usageFooterReadout
        let label = Color.white.opacity(0.72)
        let value = store.isUsageLow ? Color(hex: TaskLight.red.color) : Color.white.opacity(0.92)
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
            HStack(spacing: m.gap) {
                usagePeriodIndicator
                quotaReadout
                if let barWidth = m.inlineBarWidth {
                    progressBar.frame(width: barWidth)
                }
            }
            .padding(.horizontal, m.quotaPadding)
            .frame(height: m.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: m.corner))
            .background(
                RoundedRectangle(cornerRadius: m.corner)
                    .fill(Color.white.opacity(usageToggleHovered ? 0.1 : 0))
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
            .foregroundStyle(Color(hex: "#0F0F11"))
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "#00D4AA").opacity(loginHovered ? 0.88 : 1))
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
                                     ? Color(hex: "#0F0F11")
                                     : Color.white.opacity(0.55))
                    .frame(width: m.segWidth, height: m.segHeight)
                    .background(
                        RoundedRectangle(cornerRadius: m.segCorner)
                            .fill(isActive ? Color(hex: "#00D4AA") : Color.clear)
                    )
            }
        }
        .padding(1)
        .background(RoundedRectangle(cornerRadius: m.segCorner + 1).fill(Color.white.opacity(0.10)))
    }
}

// MARK: - 关于弹窗内容

/// 更新红点配色（#FF4D4F）。设置齿轮走 SwiftUI、菜单项勾选列走 AppKit，
/// 两处共用同一色值 —— 分开写迟早改一处漏一处，而 5px 的红点色差肉眼几乎发现不了
private enum UpdateDot {
    static let hex = "#FF4D4F"
    static let color = Color(hex: hex)
    static let nsColor = NSColor(color)
}

/// 对外链接的唯一来源（菜单的更新回退与设置窗口的关于页共用）
enum HUDLinks {
    static let website = "https://comate.wpsgo.com/s/HyDSehobOTHX/"
}

/// 主按钮：品牌绿实底 + 深色文字
private struct HUDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Color(hex: "#0F0F11"))
            .frame(width: 150, height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(AboutDesign.brand))
            .shadow(color: AboutDesign.brand.opacity(configuration.isPressed ? 0.10 : 0.22),
                    radius: 9, y: 5)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 次要按钮：浅底 + 描边
private struct HUDGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(width: 96, height: 34)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AboutHUDView: View {
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            brandGlow
            VStack(spacing: 0) {
                appIcon
                Text("Comate HUD")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                versionChip.padding(.top, 9)
                Text("让 AI 干活，你只管看灯")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AboutDesign.brand)
                    .padding(.top, 20)
                Text("一款常驻 macOS 刘海区的轻量状态指示器，为 WPS Comate 而生。无需打开主窗口，任务状态一目了然。")
                    .font(.system(size: 12))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(maxWidth: 300)
                    .padding(.top, 10)
                statusLegend.padding(.top, 20)
                featureList.padding(.top, 20)
                Spacer(minLength: 10)
                HStack(spacing: 0) {
                    Text("通过 ")
                    Text("WPS Comate 应用开发能力 Vibe Coding")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white.opacity(0.88))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(AboutDesign.brand)
                                .frame(height: 1.5)
                                .offset(y: 2)
                        }
                    Text(" 实现")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.36))
                HStack(spacing: 10) {
                    Button("访问官网", action: openWebsite)
                        .buttonStyle(HUDPrimaryButtonStyle())
                        .help("打开官网，检查更新或提交意见反馈")
                    Button("关闭", action: onClose)
                        .buttonStyle(HUDGhostButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.top, 15)
                Button(action: openWebsite) {
                    Text("检查更新 · 意见反馈 · comate.wpsgo.com")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.22))
                                .frame(height: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 13)
            }
            .padding(.horizontal, 30)
            .padding(.top, 32)
            .padding(.bottom, 22)
        }
        .frame(width: AboutDesign.width, height: AboutDesign.height)
        .background(Color(hex: "#0F0F11"))
    }

    /// 顶部品牌光晕，让图标有发光感
    private var brandGlow: some View {
        RadialGradient(colors: [Color(hex: "#937EE6").opacity(0.28),
                                Color(hex: "#4526BF").opacity(0.14),
                                .clear],
                       center: .center, startRadius: 0, endRadius: 190)
            .frame(width: AboutDesign.width, height: 320)
            .offset(y: -120)
            .allowsHitTesting(false)
    }

    private var appIcon: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }

    private var versionChip: some View {
        Text("版本 \(appVersion)")
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.58))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    /// 四色状态图例，颜色取自真实任务灯色（顺序与官网一致）
    private var statusLegend: some View {
        HStack(spacing: 0) {
            legendItem(TaskLight.gray.color, "空闲")
            legendItem(TaskLight.green.color, "已完成")
            legendItem(TaskLight.yellow.color, "工作中")
            legendItem(TaskLight.red.color, "等待确认")
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(AboutDesign.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AboutDesign.cardStroke, lineWidth: 1))
    }

    private func legendItem(_ hex: String, _ label: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 8, height: 8)
                .shadow(color: Color(hex: hex).opacity(0.6), radius: 3.5)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 9) {
            feature("悬停刘海，展开任务面板")
            feature("最近会话 · 执行进度 · 额度用量，尽收眼底")
            feature("点击任务，直达对应会话")
        }
        .frame(maxWidth: 312, alignment: .leading)
    }

    private func feature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("✓")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(AboutDesign.brand)
                .frame(width: 14, height: 14)
                .background(Circle().fill(AboutDesign.brand.opacity(0.14)))
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openWebsite() {
        guard let url = URL(string: AboutDesign.website) else { return }
        NSWorkspace.shared.open(url)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

// MARK: - 独立「关于」窗口
// 悬浮模式下的 NSPanel 是非激活面板，无法正常弹出 SwiftUI sheet，故用独立窗口承载。

enum AboutHUDWindow {
    private static var window: NSWindow?

    static func show() {
        if let w = window {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(
            rootView: AboutHUDView(onClose: { close() })
                .environment(\.colorScheme, .dark))
        let w = NSWindow(contentViewController: hosting)
        w.title = "关于 Comate HUD"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: AboutDesign.width, height: AboutDesign.height))
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - 右键 / 设置按钮菜单（刘海 HUD 与任意悬浮共用同一份定义）

/// 两种显示模式的右键菜单与设置按钮共用这一个构建器：菜单项、顺序、勾选态只有一份定义，
/// 不会再出现「某个模式少一个入口」的漂移。
///
/// 两种模式的窗口都是非激活 borderless NSPanel，SwiftUI 的 contextMenu 在其中不可靠，
/// 故统一走 AppKit NSMenu：右键由内容视图的 menu(for:) 兜住，设置按钮合成一次右键事件弹出，
/// 两条入口走完全同一条路径。
final class HUDContextMenu: NSObject {
    private let store: ComateStore
    private let onSwitchMode: (ComateStore.DisplayMode) -> Void
    private let onShowMainWindow: () -> Void
    private let onShowAbout: () -> Void
    private let onLogin: () -> Void
    private let onSignOut: () -> Void
    /// 可选的刘海屏幕（每次构建菜单时现取，屏幕热插拔后菜单自然是最新的）
    private let screenOptions: () -> [NotchScreenTarget.Option]
    /// 指定刘海屏幕（nil = 跟随主屏）
    private let onSelectScreen: (UInt32?) -> Void

    init(store: ComateStore,
         onSwitchMode: @escaping (ComateStore.DisplayMode) -> Void,
         onShowMainWindow: @escaping () -> Void,
         onShowAbout: @escaping () -> Void,
         onLogin: @escaping () -> Void,
         onSignOut: @escaping () -> Void,
         screenOptions: @escaping () -> [NotchScreenTarget.Option],
         onSelectScreen: @escaping (UInt32?) -> Void) {
        self.store = store
        self.onSwitchMode = onSwitchMode
        self.onShowMainWindow = onShowMainWindow
        self.onShowAbout = onShowAbout
        self.onLogin = onLogin
        self.onSignOut = onSignOut
        self.screenOptions = screenOptions
        self.onSelectScreen = onSelectScreen
    }

    /// 每次弹出都重新构建：勾选态、「恢复默认高度」的显隐取决于当前 store 状态
    func build() -> NSMenu {
        let menu = NSMenu()

        // 账号：这是登录失效时用户唯一能自救的地方，所以需要动作时直接置顶并带红点；
        // 已登录时收进子菜单，不占两行
        addAccountItems(to: menu)
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

        // 刘海落在哪块屏：只对刘海模式有意义，且单屏时没有可选项
        addScreenItems(to: menu)

        let mainItem = NSMenuItem(title: "打开 WPS Comate", action: #selector(menuShowMain), keyEquivalent: "")
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

        // 仅已自定义高度时提供恢复默认
        if store.hasCustomExpandedHeight {
            menu.addItem(.separator())
            let reset = NSMenuItem(title: "恢复默认高度", action: #selector(menuResetHeight), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)
        }

        // 开机自启动：勾选态直接读 LaunchAgent plist（菜单每次弹出重建，与磁盘天然一致）
        menu.addItem(.separator())
        let loginItem = NSMenuItem(title: "开机自启动", action: #selector(menuToggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        // 更新：未检测到新版时是「检查更新」，检测到新版时直接显示版本号并跳发布页
        menu.addItem(.separator())
        let updateTitle: String
        if let v = store.availableUpdate {
            updateTitle = "检测到新版 \(v)"
        } else if store.updateChecked {
            updateTitle = "已是最新版本 v\(UpdateChecker.localVersion)"
        } else {
            updateTitle = "检查更新"
        }
        let updateItem = NSMenuItem(title: updateTitle, action: #selector(menuCheckUpdate), keyEquivalent: "")
        updateItem.target = self
        // 未读新版：红点画在勾选列。该列已被「开机自启动」占用，
        // 因此不会凭空多出一个图标列、把整个菜单的标题右移
        if store.showsUpdateDot {
            updateItem.onStateImage = Self.updateDotImage
            updateItem.state = .on
        }
        menu.addItem(updateItem)

        // 关于紧贴在退出上方
        menu.addItem(.separator())
        let about = NSMenuItem(title: "关于 Comate HUD", action: #selector(menuAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "退出 Comate HUD", action: #selector(menuQuit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    /// 菜单项里的红点（与设置按钮同色，见 UpdateDot）。
    /// 用 drawingHandler 而不是 lockFocus：前者按屏幕缩放绘制，Retina 下边缘不糊
    private static let updateDotImage: NSImage = {
        let side: CGFloat = 14
        let dot: CGFloat = 7
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let rect = NSRect(x: (side - dot) / 2, y: (side - dot) / 2, width: dot, height: dot)
            UpdateDot.nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }()

    /// 账号组：需要动作时（未登录 / 已失效）直接置顶，失效时带红点
    private func addAccountItems(to menu: NSMenu) {
        switch AuthSession.shared.state {
        case .noCredential:
            menu.addItem(actionItem("登录 WPS 账号…", #selector(menuLogin)))
        case .expired:
            let item = actionItem("登录已失效，重新登录", #selector(menuLogin))
            item.onStateImage = Self.updateDotImage
            item.state = .on
            menu.addItem(item)
        case .ok:
            let account = NSMenuItem(title: "WPS 账号", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            // 登录后要能一眼看出是哪个账号、属于哪个企业：账号信息还没取到时退回「已登录」
            if let info = store.account {
                if !info.nickname.isEmpty { submenu.addItem(infoItem("账号 \(info.nickname)")) }
                if !info.companyName.isEmpty { submenu.addItem(infoItem("企业 \(info.companyName)")) }
            } else {
                submenu.addItem(infoItem("已登录"))
            }
            submenu.addItem(.separator())
            submenu.addItem(actionItem("退出登录", #selector(menuSignOut)))
            account.submenu = submenu
            menu.addItem(account)
        case .unknown:
            let item = NSMenuItem(title: "正在检查登录状态…", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    /// 「刘海所在屏幕」子菜单。勾选态标的是**用户的选择**而不是「当前生效」（选中的屏被拔掉时
    /// 会临时用主屏，顶上那一行说明去向）—— 两者混用会让菜单看不出自己到底选了什么
    private func addScreenItems(to menu: NSMenu) {
        guard store.displayMode == .notchHUD else { return }
        let options = screenOptions()
        guard NotchScreenTarget.shouldShowMenu(screenCount: options.count) else { return }
        let saved = store.notchScreenID

        let item = NSMenuItem(title: "刘海所在屏幕", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if let saved = saved, !options.contains(where: { $0.id == saved }) {
            submenu.addItem(infoItem("已选屏幕未连接，当前用主屏幕"))
        }
        let follow = actionItem("跟随主屏幕", #selector(menuSelectScreen(_:)))
        if saved == nil { follow.state = .on }
        submenu.addItem(follow)
        for option in options {
            let row = actionItem(option.name, #selector(menuSelectScreen(_:)))
            row.representedObject = NSNumber(value: option.id)
            if saved == option.id { row.state = .on }
            submenu.addItem(row)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    private func actionItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    /// 纯展示行（不可点，不响应键盘）
    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func menuSwitchMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ComateStore.DisplayMode(rawValue: raw) else { return }
        onSwitchMode(mode)
    }

    @objc private func menuSelectScreen(_ sender: NSMenuItem) {
        onSelectScreen((sender.representedObject as? NSNumber)?.uint32Value)
    }

    @objc private func menuShowMain() { onShowMainWindow() }

    @objc private func menuSetLimit(_ sender: NSMenuItem) { store.recentTaskLimit = sender.tag }

    @objc private func menuResetHeight() { store.resetCustomExpandedHeight() }

    /// 有新版 → 先记为「已读」（红点消失、该版本不再提示），再打开发布页
    /// （GitHub Release 公开可访问；拿不到链接时退回官网）；
    /// 否则立即重新检查一次（不受 6 小时节流限制）
    @objc private func menuCheckUpdate() {
        guard store.hasUpdate else {
            store.checkForUpdate(force: true)
            return
        }
        store.acknowledgeUpdate()
        if let url = store.availableUpdateURL {
            NSWorkspace.shared.open(url)
        } else if let site = URL(string: AboutDesign.website) {
            NSWorkspace.shared.open(site)
        }
    }

    /// 开机自启动开关。写盘前先确认路径稳定，否则重启后不会生效
    @objc private func menuToggleLaunchAtLogin() {
        let target = !LaunchAtLogin.isEnabled
        if target, !LaunchAtLogin.isPathStable {
            LaunchAtLogin.warnPathUnstable()
            return
        }
        LaunchAtLogin.setEnabled(target)
    }

    @objc private func menuAbout() { onShowAbout() }

    @objc private func menuLogin() { onLogin() }

    @objc private func menuSignOut() { onSignOut() }

    @objc private func menuQuit() {
        store.stop()
        NSApp.terminate(nil)
    }
}

/// 承载菜单的内容视图：右键沿 superview 向上找到这里，设置按钮直接弹出同一份菜单。
final class HUDMenuHostView: NSView {
    /// 强引用构建器：NSMenuItem.target 是 weak，构建器一旦被释放菜单项就点不动了
    var menuBuilder: HUDContextMenu?

    override func menu(for event: NSEvent) -> NSMenu? { menuBuilder?.build() }

    /// 设置按钮：与右键走完全相同的弹出手径
    func showMenu() {
        guard let menu = menuBuilder?.build() else { return }
        popUpHUDMenu(menu)
    }
}

extension NSView {
    /// 在当前鼠标位置弹出菜单。
    /// 非激活 borderless 面板里直接 popUp 不可靠，故合成一次右键按下事件，
    /// 复用与真实右键完全一致的路径（该路径已验证可用）。
    func popUpHUDMenu(_ menu: NSMenu) {
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
}
