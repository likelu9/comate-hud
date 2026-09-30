import AppKit
import SwiftUI

/// 设置窗口的四个分类。菜单项「设置…」进账号页、「关于 Comate HUD」直接进关于页。
enum SettingsPage: String, CaseIterable, Identifiable {
    case account
    case display
    case general
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .account: return "账号"
        case .display: return "显示"
        case .general: return "通用"
        case .about:   return "关于"
        }
    }

    var symbol: String {
        switch self {
        case .account: return "person.circle"
        case .display: return "display"
        case .general: return "gearshape"
        case .about:   return "info.circle"
        }
    }
}

/// 设置窗口需要的两个「会动窗口」的动作。
/// 显示模式要重建面板、换屏要重新解析刘海几何 —— 这两件事都不属于设置窗口，
/// 只能由持有面板的 AppDelegate 来做，所以以闭包注入而不是让设置窗口自己改 store。
struct SettingsActions {
    var switchMode: (ComateStore.DisplayMode) -> Void
    var selectScreen: (UInt32?) -> Void

    /// 兜底：只写 store、不动窗口。用于没有面板上下文时（理论上不会走到）
    static let inert = SettingsActions(switchMode: { _ in }, selectScreen: { _ in })
}

/// 设置窗口的尺寸与取色（与设计稿 §7.2 同一套值）
private enum SettingsDesign {
    static let width: CGFloat = 560
    static let height: CGFloat = 480
    static let navWidth: CGFloat = 148
    static let padH: CGFloat = 20
    static let padTop: CGFloat = 18
    static let padBottom: CGFloat = 20
    static let rowHeight: CGFloat = 34
    static let cardRadius: CGFloat = 8
    static let cardFill = Color.white.opacity(0.045)
    static let cardStroke = Color.white.opacity(0.07)
    static let divider = Color.white.opacity(0.08)
    /// 左导航底：比内容区略亮一档，靠 1px 分隔线收边
    static let raised = Color.white.opacity(0.05)
    static let hit = Color.white.opacity(0.10)
    static let brand = Color(hex: "#00D4AA")
    /// 绿底上的文字一律深墨（白字压绿的对比度只有 ≈1.9:1）
    static let brandInk = Color(hex: "#0F0F11")
    static let warning = Color(hex: "#FF6259")
    static let website = "https://comate.wpsgo.com/s/HyDSehobOTHX/"
}

/// 当前选中的分类。窗口复用时靠它从菜单跳到指定页。
final class SettingsSelection: ObservableObject {
    @Published var page: SettingsPage = .account
}

// MARK: - 窗口

/// 设置窗口。原「关于」独立弹窗已退场，内容并入本窗口的关于页。
///
/// 为什么仍是独立窗口而不是面板内的 sheet：两种模式的 HUD 窗口都是非激活 borderless 面板，
/// 挂不上 SwiftUI sheet（与登录窗、原关于窗同一个原因）。
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var selection = SettingsSelection()
    private var actions = SettingsActions.inert
    private weak var store: ComateStore?

    private init() {}

    func present(page: SettingsPage, store: ComateStore, actions: SettingsActions) {
        self.store = store
        self.actions = actions
        selection.page = page

        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsRootView(store: store, selection: selection, actions: actions)
                .environment(\.colorScheme, .dark))
        let w = NSWindow(contentViewController: hosting)
        w.title = "设置"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: SettingsDesign.width, height: SettingsDesign.height))
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    /// 窗口已关但拉起来的那份 store 还在（isReleasedWhenClosed = false）：
    /// 这里只做置前，不做重建，避免用户设置到一半被重建回默认页
    func show(page: SettingsPage) {
        guard let window = window else { return }
        selection.page = page
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 根视图

private struct SettingsRootView: View {
    @ObservedObject var store: ComateStore
    @ObservedObject var selection: SettingsSelection
    let actions: SettingsActions

    var body: some View {
        HStack(spacing: 0) {
            nav
            content
        }
        .frame(width: SettingsDesign.width, height: SettingsDesign.height)
        .background(Color(hex: "#0F0F11"))
    }

    private var nav: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPage.allCases) { page in
                Button { selection.page = page } label: {
                    HStack(spacing: 8) {
                        Image(systemName: page.symbol)
                            .font(.system(size: 12))
                            .frame(width: 16)
                        Text(page.label)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selection.page == page
                                     ? Color.white.opacity(0.92)
                                     : Color.white.opacity(0.55))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(selection.page == page ? SettingsDesign.hit : Color.clear))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .frame(width: SettingsDesign.navWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SettingsDesign.raised)
        .overlay(alignment: .trailing) {
            Rectangle().fill(SettingsDesign.divider).frame(width: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection.page {
        case .account:
            AccountSettingsPage(store: store)
        case .display:
            DisplaySettingsPage(store: store, actions: actions)
        case .general:
            GeneralSettingsPage(store: store)
        case .about:
            AboutSettingsPage(store: store)
        }
    }
}

/// 内容区统一外壳：右页内边距 18/20/20，纵向滚动（关于页在新容器里放不下一屏）
private struct SettingsPageBody<Content: View>: View {
    var scrolls: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if scrolls {
                ScrollView(.vertical, showsIndicators: false) { stack }
            } else {
                stack
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(.horizontal, SettingsDesign.padH)
            .padding(.top, SettingsDesign.padTop)
            .padding(.bottom, SettingsDesign.padBottom)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 通用组件

/// 分区：小标题 + 卡片
private struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
                    .fill(SettingsDesign.cardFill))
                .overlay(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
                    .strokeBorder(SettingsDesign.cardStroke, lineWidth: 1))
        }
    }
}

/// 卡片内的一行：标题（可带副标题）+ 右侧控件
private struct SettingsRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.88))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .frame(minHeight: SettingsDesign.rowHeight)
    }
}

/// 卡片内的行分隔线。首行之前不画，最后一行之后不画 —— 由调用方决定放哪
private struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsDesign.divider)
            .frame(height: 1)
            .padding(.horizontal, 12)
    }
}

/// 单选：设计稿要求选项最小宽 132，避免长短不一的标签让两列对不齐
private struct SettingsRadio: View {
    var label: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isOn ? SettingsDesign.brand : Color.white.opacity(0.4))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(isOn ? 0.92 : 0.7))
            }
            .frame(minWidth: 132, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 行内动作按钮：绿字 + 浅底。不用绿底 —— 绿底要配深墨字，在设置窗口里视觉重量过大
private struct SettingsActionButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(enabled ? SettingsDesign.brand : Color.white.opacity(0.32))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(enabled ? 0.06 : 0.03)))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// 警示条：登录失效等需要用户动作的状态。
/// 刻意不用红色块 —— 红在这套视觉里是「任务异常」的状态语义，占掉就分不清了
private struct SettingsWarning: View {
    var text: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(SettingsDesign.warning)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(SettingsDesign.warning)
            Spacer(minLength: 8)
            SettingsActionButton(title: actionTitle, action: action)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: SettingsDesign.rowHeight)
        .background(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
            .fill(SettingsDesign.warning.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
            .strokeBorder(SettingsDesign.warning.opacity(0.22), lineWidth: 1))
    }
}

/// 更新行：三态文案 + 动作。设置窗口的通用页与关于页共用同一份判定
private struct SettingsUpdateRow: View {
    @ObservedObject var store: ComateStore

    var body: some View {
        SettingsRow(title: "检查更新", subtitle: subtitle) {
            switch state {
            case .available:
                SettingsActionButton(title: "前往下载", action: openRelease)
            case .latest:
                SettingsActionButton(title: "重新检查", action: { store.checkForUpdate(force: true) })
            case .idle:
                SettingsActionButton(title: "检查更新", action: { store.checkForUpdate(force: true) })
            }
        }
    }

    private enum State { case idle, latest, available }

    private var state: State {
        if store.hasUpdate { return .available }
        return store.updateChecked ? .latest : .idle
    }

    private var subtitle: String {
        switch state {
        case .available:
            let v = store.availableUpdate ?? ""
            return store.showsUpdateDot ? "检测到新版 \(v)" : "检测到新版 \(v)（已标记为已读）"
        case .latest:
            return "已是最新版本 v\(UpdateChecker.localVersion)"
        case .idle:
            return "尚未检查过"
        }
    }

    /// 与菜单同一条路径：先记为「已读」（红点消失），再打开发布页；拿不到链接退回官网
    private func openRelease() {
        store.acknowledgeUpdate()
        if let url = store.availableUpdateURL {
            NSWorkspace.shared.open(url)
        } else if let site = URL(string: SettingsDesign.website) {
            NSWorkspace.shared.open(site)
        }
    }
}

// MARK: - 账号

private struct AccountSettingsPage: View {
    @ObservedObject var store: ComateStore

    var body: some View {
        SettingsPageBody {
            header
            if store.needsLogin { loginWarning }
            accountSection
        }
    }

    /// 头图：头像 + 昵称 + 归属企业。
    /// 三者都取真实数据（`store.account`）—— 取不到就退回「未登录 / 已登录」，不编造企业名
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(SettingsDesign.brand.opacity(0.16))
                if let initial = avatarInitial {
                    Text(initial)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SettingsDesign.brand)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(nickname)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(company)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 8)
        }
        .padding(.top, 2)
    }

    private var accountSection: some View {
        SettingsSection(title: "WPS 账号") {
            SettingsRow(title: "登录状态", subtitle: statusSubtitle) {
                if store.needsLogin {
                    SettingsActionButton(title: "登录") { presentLogin() }
                } else {
                    SettingsActionButton(title: "退出登录") { AuthSession.shared.signOut() }
                }
            }
            if !store.needsLogin {
                SettingsRowDivider()
                SettingsRow(title: "凭据", subtitle: "只保留在本次运行的内存里，退出应用即失效") {
                    EmptyView()
                }
            }
        }
    }

    private var loginWarning: some View {
        SettingsWarning(text: store.usageState == .authExpired ? "登录已失效，额度与未读消息已停止更新" : "尚未登录，额度与未读消息不可用",
                        actionTitle: "重新登录") { presentLogin() }
    }

    private var nickname: String {
        guard AuthSession.shared.state == .ok else { return "未登录" }
        if let name = store.account?.nickname, !name.isEmpty { return name }
        return "已登录"
    }

    private var company: String {
        guard AuthSession.shared.state == .ok else { return "登录后显示账号与归属企业" }
        if let company = store.account?.companyName, !company.isEmpty { return company }
        return "账号信息读取中…"
    }

    private var avatarInitial: String? {
        guard AuthSession.shared.state == .ok,
              let name = store.account?.nickname, !name.isEmpty,
              let first = name.first else { return nil }
        return String(first)
    }

    private var statusSubtitle: String {
        switch store.usageState {
        case .ok:           return "已登录，额度与未读消息正常"
        case .noCredential: return "未登录"
        case .authExpired:  return "登录已失效，需要重新登录"
        case .failed:       return "已登录，但用量接口暂时取不到数据"
        case .idle:         return "正在确认登录状态…"
        }
    }

    private func presentLogin() {
        LoginWindowController.shared.present(refreshing: store)
    }
}

// MARK: - 显示

private struct DisplaySettingsPage: View {
    @ObservedObject var store: ComateStore
    let actions: SettingsActions

    var body: some View {
        SettingsPageBody {
            modeSection
            if store.displayMode == .notchHUD, screenOptions.count > 1 { screenSection }
            listSection
        }
    }

    private var modeSection: some View {
        SettingsSection(title: "显示模式") {
            SettingsRow(title: "形态", subtitle: modeHint) {
                HStack(spacing: 12) {
                    ForEach(ComateStore.DisplayMode.allCases, id: \.self) { mode in
                        SettingsRadio(label: mode.label, isOn: store.displayMode == mode) {
                            actions.switchMode(mode)
                        }
                    }
                }
            }
        }
    }

    private var screenSection: some View {
        SettingsSection(title: "刘海") {
            SettingsRow(title: "刘海所在屏幕", subtitle: missingSelectionHint) {
                Picker("", selection: screenBinding) {
                    Text("跟随主屏幕").tag(ScreenTag.follow)
                    ForEach(screenOptions, id: \.id) { option in
                        Text(option.name).tag(ScreenTag.screen(option.id))
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 150)
            }
        }
    }

    private var listSection: some View {
        SettingsSection(title: "任务列表") {
            SettingsRow(title: "最近记录条数", subtitle: "展开面板里最多显示几条") {
                Picker("", selection: limitBinding) {
                    ForEach(ComateStore.recentTaskLimitOptions, id: \.self) { n in
                        Text("最近 \(n) 条").tag(n)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 130)
            }
            if store.hasCustomExpandedHeight {
                SettingsRowDivider()
                SettingsRow(title: "面板高度", subtitle: "已手动拖拽过，恢复为按内容自适应") {
                    SettingsActionButton(title: "恢复默认高度") { store.resetCustomExpandedHeight() }
                }
            }
        }
    }

    private var limitBinding: Binding<Int> {
        Binding(get: { store.recentTaskLimit }, set: { store.recentTaskLimit = $0 })
    }

    /// 屏幕用 tag 承载（UInt32? 不能直接当 selection）
    private enum ScreenTag: Hashable {
        case follow
        case screen(UInt32)
    }

    private var screenBinding: Binding<ScreenTag> {
        Binding(
            get: {
                guard let id = store.notchScreenID else { return .follow }
                return .screen(id)
            },
            set: { tag in
                switch tag {
                case .follow: actions.selectScreen(nil)
                case .screen(let id): actions.selectScreen(id)
                }
            })
    }

    private var screenOptions: [NotchScreenTarget.Option] { NotchPanel.screenOptions() }

    private var modeHint: String {
        switch store.displayMode {
        case .notchHUD: return "常驻刘海，悬停展开"
        case .floating: return "悬浮窗，可拖到任意位置"
        }
    }

    /// 选中的屏被拔掉时，菜单里会顶一行说明；设置页把它降级成副标题，避免多出一行空白
    private var missingSelectionHint: String? {
        guard let saved = store.notchScreenID, !screenOptions.contains(where: { $0.id == saved }) else {
            return nil
        }
        return "已选屏幕未连接，当前用主屏幕"
    }
}

// MARK: - 通用

private struct GeneralSettingsPage: View {
    @ObservedObject var store: ComateStore

    var body: some View {
        SettingsPageBody {
            SettingsSection(title: "启动") {
                SettingsRow(title: "开机自启动", subtitle: "登录 macOS 后自动运行 Comate HUD") {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            SettingsSection(title: "更新") {
                SettingsUpdateRow(store: store)
            }
        }
    }

    /// 写盘前先确认路径稳定（不稳定就只提示、不写），与菜单同一条约束
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { target in
                if target, !LaunchAtLogin.isPathStable {
                    LaunchAtLogin.warnPathUnstable()
                    return
                }
                LaunchAtLogin.setEnabled(target)
                // 勾选态直接读 LaunchAgent plist 现算，这里推一次刷新让开关回到真实状态
                store.objectWillChange.send()
            })
    }
}

// MARK: - 关于

/// 原「关于」独立弹窗的内容整体并入此处（弹窗已退场）。
/// 文案与图形全部沿用原稿，只把尺寸压到设置窗口能放下的一档
private struct AboutSettingsPage: View {
    @ObservedObject var store: ComateStore

    var body: some View {
        SettingsPageBody {
            VStack(spacing: 0) {
                appIcon
                Text("Comate HUD")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                versionChip.padding(.top, 6)
                Text("让 AI 干活，你只管看灯")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SettingsDesign.brand)
                    .padding(.top, 12)
                Text("一款常驻 macOS 刘海区的轻量状态指示器，为 WPS Comate 而生。无需打开主窗口，任务状态一目了然。")
                    .font(.system(size: 11.5))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(maxWidth: 300)
                    .padding(.top, 8)
                statusLegend.padding(.top, 14)
                featureList.padding(.top, 14)
                Text("通过 \(signedBy) 实现")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.36))
                    .padding(.top, 12)
                Button("访问官网") { openWebsite() }
                    .buttonStyle(HUDPrimaryButtonStyle())
                    .help("打开官网，检查更新或提交意见反馈")
                    .padding(.top, 12)
                Button(action: openWebsite) {
                    Text("检查更新 · 意见反馈 · comate.wpsgo.com")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.white.opacity(0.22)).frame(height: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .background(alignment: .top) { brandGlow }
            .padding(.top, 2)

            SettingsSection(title: "更新") {
                SettingsUpdateRow(store: store)
            }
        }
    }

    /// 顶部品牌氛围光：整套视觉里唯一保留紫色的地方（设计稿 T11），只作氛围
    private var brandGlow: some View {
        RadialGradient(colors: [Color(hex: "#937EE6").opacity(0.28),
                                Color(hex: "#4526BF").opacity(0.14),
                                .clear],
                       center: .center, startRadius: 0, endRadius: 190)
            .frame(height: 280)
            .offset(y: -110)
            .allowsHitTesting(false)
    }

    private var appIcon: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 12, y: 8)
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
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
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(SettingsDesign.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(SettingsDesign.cardStroke, lineWidth: 1))
    }

    private func legendItem(_ hex: String, _ label: String) -> some View {
        HStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 8) {
            feature("悬停刘海，展开任务面板")
            feature("最近会话 · 执行进度 · 额度用量，尽收眼底")
            feature("点击任务，直达对应会话")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("✓")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(SettingsDesign.brand)
                .frame(width: 14, height: 14)
                .background(Circle().fill(SettingsDesign.brand.opacity(0.14)))
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signedBy: AttributedString {
        var bold = AttributedString("WPS Comate 应用开发能力 Vibe Coding")
        bold.font = .system(size: 10.5, weight: .bold)
        bold.foregroundColor = Color.white.opacity(0.88)
        var plain = AttributedString("通过 ")
        plain.font = .system(size: 10.5)
        var tail = AttributedString(" 实现")
        tail.font = .system(size: 10.5)
        return plain + bold + tail
    }

    private func openWebsite() {
        guard let url = URL(string: SettingsDesign.website) else { return }
        NSWorkspace.shared.open(url)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

/// 主按钮：品牌绿实底 + 深墨字（白字压绿的对比度只有 ≈1.9:1）
private struct HUDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(SettingsDesign.brandInk)
            .frame(width: 150, height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(SettingsDesign.brand))
            .shadow(color: SettingsDesign.brand.opacity(configuration.isPressed ? 0.10 : 0.22),
                    radius: 9, y: 5)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
