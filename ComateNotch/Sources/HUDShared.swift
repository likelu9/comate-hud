import AppKit
import SwiftUI

// MARK: - 图标 + 状态灯（刘海模式 / 悬浮模式共用）
// 灯的尺寸与偏移都按 logo 尺寸等比缩放（以 18pt logo 为基准），
// 保证两种模式下灯与图标的相对位置、紧凑度完全一致。

struct HUDLogoBadge: View {
    @ObservedObject var store: ComateStore
    var logoSize: CGFloat
    var lightSize: CGFloat
    /// 状态灯光晕强度：1 = 刘海模式基准；悬浮模式图标更大，需收敛避免光晕发散
    var glow: CGFloat = 1
    var colorful: Bool = true

    @State private var pulseOpacity: Double = 1.0

    private var scale: CGFloat { logoSize / 18 }

    /// 状态灯脉冲：黄灯跳动（工作中），红灯快闪（等你确认）。nil = 常亮
    /// 谷值不是 0：灯完全熄灭时读起来像「灯没了」，保留约四分之一亮度 + 等比光晕，
    /// 才是「亮-暗-亮-暗」的呼吸感。实测 0.05 时灯本体压在彩色 logo 上会糊掉、
    /// 只剩一圈光晕，故黄灯取 0.25、红灯（闪得更快、更急）取 0.35。
    /// 灯与光晕同一图层、同比缩放，不会出现「灯灭了光晕还在」的脱节。
    private var pulse: (duration: Double, low: Double)? {
        if store.primaryLight == .yellow { return (1.2, 0.25) }
        if store.primaryLight == .red && store.primaryRedBlinking { return (0.55, 0.35) }
        return nil
    }

    /// 重启脉冲动画。repeatForever 动画一旦启动就不会自己停，所以换状态时必须显式重置，
    /// 否则会叠加出多个动画。
    private func restartPulse() {
        pulseOpacity = 1.0
        guard let pulse = pulse else { return }
        withAnimation(.easeInOut(duration: pulse.duration).repeatForever(autoreverses: true)) {
            pulseOpacity = pulse.low
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ComateLogo(size: logoSize, colorful: colorful)
            // 状态灯：压在 logo 右下角，与图标紧凑贴合
            Circle()
                .fill(Color(hex: store.primaryLight.color))
                .frame(width: lightSize, height: lightSize)
                .overlay(
                    Circle()
                        .fill(Color(hex: store.primaryLight.color)
                            .opacity(store.primaryLight != .gray ? 0.45 * glow : 0))
                        .frame(width: lightSize * 2, height: lightSize * 2)
                        .blur(radius: 3 * scale * glow)
                )
                .shadow(
                    color: store.primaryLight != .gray
                        ? Color(hex: store.primaryLight.color)
                            .opacity((store.primaryLight == .red ? 0.9 : 0.7) * glow)
                        : .clear,
                    radius: 4 * scale * glow
                )
                .shadow(
                    color: store.primaryLight != .gray
                        ? Color(hex: store.primaryLight.color)
                            .opacity((store.primaryLight == .red ? 0.6 : 0.4) * glow)
                        : .clear,
                    radius: 8 * scale * glow
                )
                .opacity(pulseOpacity)
                .onAppear { restartPulse() }
                .onChange(of: store.primaryLight) { _ in restartPulse() }
                .onChange(of: store.primaryRedBlinking) { _ in restartPulse() }
                .offset(x: 13.5 * scale, y: 13.5 * scale)
        }
        // 布局盒子固定为 logo 尺寸（灯溢出部分不参与布局，但不会被裁切）
        .frame(width: logoSize, height: logoSize, alignment: .topLeading)
    }
}

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

/// 页脚三个按钮的统一热区。原来只有图标本身那么大（约 13pt 高），难点中，
/// 这里统一高度、并给右侧两个按钮一个统一的最小宽度。
private enum FooterHit {
    static let height: CGFloat = 20
    static let sideWidth: CGFloat = 30
    static let corner: CGFloat = 5
}

struct HUDUsageFooter: View {
    @ObservedObject var store: ComateStore
    /// 设置按钮动作。必填而非可选：设置是功能而不是装饰，
    /// 两种显示模式都必须提供，避免再出现「某个模式没有设置按钮」
    let onSettings: () -> Void

    @State private var usageToggleHovered = false
    @State private var bellHovered = false
    @State private var settingsHovered = false
    @State private var bellRotate = false

    var body: some View {
        HStack(spacing: 6) {
            // 周期切换：胶囊 + 文案一起点，热区仅覆盖内容本身（不占满整行）
            Button(action: { store.toggleUsagePeriod() }) {
                HStack(spacing: 6) {
                    usagePeriodIndicator
                    Text("额度已用 \(store.activeUsageLabel)")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        // 与周期色块同色（品牌绿），hover 时提亮到全不透明
                        .foregroundStyle(Color(hex: "#00D4AA")
                            .opacity(usageToggleHovered ? 1.0 : 0.85))
                }
                .padding(.horizontal, 6)
                .frame(height: FooterHit.height)
                .contentShape(RoundedRectangle(cornerRadius: FooterHit.corner))
                .background(
                    RoundedRectangle(cornerRadius: FooterHit.corner)
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

            Spacer(minLength: 0)

            // 消息数提示：铃铛图标 + 未读数（可点击打开消息中心）
            if store.totalMessageCount > 0 {
                Button(action: { store.openMessageCenter() }) {
                    HStack(spacing: 3) {
                        if store.isOpeningMessageCenter {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.system(size: 9))
                                .rotationEffect(.degrees(bellRotate ? 360 : 0))
                                .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: bellRotate)
                                .onAppear { bellRotate = true }
                        } else {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 9))
                                .scaleEffect(bellHovered ? 1.2 : 1.0)
                        }
                        Text("\(store.totalMessageCount)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(bellHovered || store.isOpeningMessageCenter ? 0.9 : 0.55))
                    .frame(minWidth: FooterHit.sideWidth, minHeight: FooterHit.height)
                    .contentShape(RoundedRectangle(cornerRadius: FooterHit.corner))
                    .background(
                        Color.white.opacity(bellHovered ? 0.12 : 0)
                            .clipShape(RoundedRectangle(cornerRadius: FooterHit.corner))
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

            // 设置：等同右键，弹出与右键一致的菜单（两种模式都有）
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 9))
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
                    .frame(width: FooterHit.sideWidth, height: FooterHit.height)
                    .contentShape(RoundedRectangle(cornerRadius: FooterHit.corner))
                    .background(
                        Color.white.opacity(settingsHovered ? 0.12 : 0)
                            .clipShape(RoundedRectangle(cornerRadius: FooterHit.corner))
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
    }

    /// 额度周期指示：双段胶囊（日 | 月），高亮当前周期。纯视觉，点击由外层按钮接管
    private var usagePeriodIndicator: some View {
        HStack(spacing: 0) {
            ForEach(UsageAPI.Period.allCases, id: \.self) { period in
                let isActive = store.usagePeriod == period
                Text(period.shortLabel)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    // 选中段用纯白（绿底上对比度最高），未选中段弱化
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 13, height: 11)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(isActive ? Color(hex: "#00D4AA").opacity(0.85) : Color.clear)
                    )
            }
        }
        .padding(1)
        .background(RoundedRectangle(cornerRadius: 4.5).fill(Color.white.opacity(0.1)))
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

/// 「关于」弹窗的设计常量
private enum AboutDesign {
    static let width: CGFloat = 420
    static let height: CGFloat = 556
    static let brand = Color(hex: "#00D4AA")
    static let cardFill = Color.white.opacity(0.045)
    static let cardStroke = Color.white.opacity(0.07)
    static let website = "https://comate.wpsgo.com/s/HyDSehobOTHX/"
}

/// 主按钮：品牌绿实底 + 深色文字
private struct HUDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Color(hex: "#06251F"))
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

    init(store: ComateStore,
         onSwitchMode: @escaping (ComateStore.DisplayMode) -> Void,
         onShowMainWindow: @escaping () -> Void,
         onShowAbout: @escaping () -> Void) {
        self.store = store
        self.onSwitchMode = onSwitchMode
        self.onShowMainWindow = onShowMainWindow
        self.onShowAbout = onShowAbout
    }

    /// 每次弹出都重新构建：勾选态、「恢复默认高度」的显隐取决于当前 store 状态
    func build() -> NSMenu {
        let menu = NSMenu()

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

    @objc private func menuSwitchMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ComateStore.DisplayMode(rawValue: raw) else { return }
        onSwitchMode(mode)
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
