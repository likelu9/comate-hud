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

    /// 侧栏图标，取 `settings.html` 内联 SVG 的同义 SF Symbol：
    /// user → person.crop.circle、display → display、general（三滑杆）→ slider.horizontal.3、info → info.circle
    var symbol: String {
        switch self {
        case .account: return "person.crop.circle"
        case .display: return "display"
        case .general: return "slider.horizontal.3"
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
    /// 打开 WPS Comate 主程序。原右键菜单的「打开 Comate」入口，
    /// 菜单下线后改从账号页进入（用户反馈 ②）
    var openComateApp: () -> Void
    /// 退出 Comate HUD。原右键菜单的「退出」入口，
    /// 菜单下线后先放关于页，用户反馈太隐蔽 → 现常驻左侧导航底部（项名「退出 HUD」）
    var quit: () -> Void

    /// 兜底：只写 store、不动窗口。用于没有面板上下文时（理论上不会走到）
    static let inert = SettingsActions(switchMode: { _ in }, selectScreen: { _ in },
                                       openComateApp: {}, quit: {})
}

/// 设置窗口的全部几何与取色。取色一律从 `HUDDesign` 转（§2 单一来源），
/// 这里只放「设置窗口专属」的几何量（窗口 / 侧栏 / 行 / 控件 / 关于页尺寸）。
private enum SettingsDesign {
    // 窗口（settings.html：--w-w 560 · --w-h 480（含自带 28pt 标题栏）· 圆角 radius.12）
    static let width: CGFloat = 560
    /// 窗口总高。稿里的 480 含它自带的 28pt 标题栏（--w-tb），而本应用用系统标题栏，
    /// 所以内容区只占 452（= 480 − 28，与稿「内容区可视 452pt」一致）。
    ///
    /// 高度随后由 480 上调到 560（内容区 532）：用户反馈关于页要滚动才能看全。
    /// 稿自己算过「一屏零滚动」的下限就是 560×560，这里是回到那个值，宽度不变
    static let height: CGFloat = 560
    static let titlebarH: CGFloat = 28
    static let contentHeight: CGFloat = height - titlebarH
    static let windowRadius: CGFloat = HUDDesign.radiusWindow

    // 左侧导航（--nav-w 148 · 内边距 10/8 · 项高 --nav-h 32 · 间距 space.2 · 圆角 radius.6）
    static let navWidth: CGFloat = 148
    static let navPadV: CGFloat = 10
    static let navPadH: CGFloat = 8
    static let navItemH: CGFloat = 32
    static let navItemRadius: CGFloat = HUDDesign.radiusMiddle
    static let navItemGap: CGFloat = 2
    static let navItemPadH: CGFloat = 8
    static let navIconGap: CGFloat = 8
    static let navIcon: CGFloat = 14
    static let navFont: CGFloat = 13
    static let navFootFont: CGFloat = 9

    // 右内容区（内边距 18 / 20 / 20）
    static let padH: CGFloat = 20
    static let padTop: CGFloat = 18
    static let padBottom: CGFloat = 20
    /// 页标题 font.h1 14/600 · 页副标 font.meta 9
    static let pageTitleFont: CGFloat = 14
    static let pageSubFont: CGFloat = 9
    /// 组标题 font.label 12/600 · 标题下距 space.6 · 组间距 space.16
    static let groupTitleFont: CGFloat = 12
    static let groupTitleGap: CGFloat = 6
    static let groupGap: CGFloat = 16

    // 行 / 分组卡片（行高 38 · 行内 6/10 · 行内块间距 space.12 · 圆角 radius.8）
    static let rowMinH: CGFloat = 38
    static let rowPadV: CGFloat = 6
    static let rowPadH: CGFloat = 10
    static let rowGap: CGFloat = 12
    static let rowTitleFont: CGFloat = 13
    static let rowSubFont: CGFloat = 11.5
    static let rowValueFont: CGFloat = 12.5
    static let cardRadius: CGFloat = HUDDesign.radiusLarge

    // 控件（高 --ctl-h 24 · 圆角 radius.6 · 字 font.btn 12.5/600）
    static let ctlH: CGFloat = 24
    static let ctlRadius: CGFloat = HUDDesign.radiusMiddle
    static let ctlFont: CGFloat = 12.5
    static let popMinW: CGFloat = 132
    static let radioSize: CGFloat = 14
    static let switchW: CGFloat = 34
    static let switchH: CGFloat = 20
    static let switchKnob: CGFloat = 16
    static let chevron: CGFloat = 12

    // 关于页（settings.html 三 · 关于）
    static let aboutNameFont: CGFloat = 22
    static let aboutChipFont: CGFloat = 10.5
    static let aboutTaglineFont: CGFloat = 13
    static let aboutDescFont: CGFloat = 12
    static let aboutDescWidth: CGFloat = 300
    static let aboutCTAWidth: CGFloat = 150
    static let aboutCTAHeight: CGFloat = 30
    static let legendRadius: CGFloat = HUDDesign.radiusCard
    /// 图例里的状态徽标尺寸：与面板左上那枚 `LogoMotionBadge` 同尺寸（刘海/悬浮均 28pt），
    /// 1:1 复现面板真身；18pt 以下光轨会细到看不出在转，故不取更小值。
    static let legendBadge: CGFloat = 28

    /// 登录失效警示：底 status.waiting-soft，描边 rgba(255,98,89,.32)（HUDDesign 无 line.warn，由此派生）
    static let warnLine = HUDDesign.waiting.opacity(0.32)

    /// 「关于」页顶部品牌氛围光：整套视觉里唯一保留紫色的地方（T11，唯一例外，
    /// 不参与交互与状态，因此不登记进 HUDDesign 的通用 token）。
    static let glowP1 = Color(hex: "#937EE6")
    static let glowP2 = Color(hex: "#4526BF")
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
        w.setContentSize(NSSize(width: SettingsDesign.width, height: SettingsDesign.contentHeight))
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 根视图

private struct SettingsRootView: View {
    @ObservedObject var store: ComateStore
    @ObservedObject var selection: SettingsSelection
    let actions: SettingsActions

    var body: some View {
        HStack(spacing: 0) {
            SettingsNav(selection: selection, showsUpdateDot: store.showsUpdateDot,
                        onQuit: actions.quit)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 窗口底 surface.panel；tint 让系统控件（下拉菜单高亮 / 焦点环）随品牌绿走
        .background(HUDDesign.panel)
        .tint(HUDDesign.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch selection.page {
        case .account:
            AccountSettingsPage(store: store, actions: actions)
        case .display:
            DisplaySettingsPage(store: store, actions: actions)
        case .general:
            GeneralSettingsPage(store: store, actions: actions)
        case .about:
            AboutSettingsPage(actions: actions)
        }
    }
}

// MARK: - 左侧导航

/// 左分类导航 148pt：surface.raised 底 + line.divider 右侧收边。
private struct SettingsNav: View {
    @ObservedObject var selection: SettingsSelection
    /// 检测到新版时在「通用」项右侧亮 5pt 红点（稿 .nav-dot）：
    /// 入口链的最后一段 —— 齿轮红点把用户带进设置窗，侧栏红点再把他指到更新行
    var showsUpdateDot: Bool = false
    /// 退出 Comate HUD。原先挂在关于页底部，用户反馈太隐蔽 → 移到左侧导航底部
    var onQuit: () -> Void = {}

    @State private var quitHovered = false

    /// 退出入口（nav 项同构：同高同图标位，只是色调更低不抢注意力）。
    /// 原右键菜单的「退出」随菜单下线，用户又反馈关于页底部太隐蔽，故常驻左侧导航
    private var quitItem: some View {
        Button(action: onQuit) {
            HStack(spacing: SettingsDesign.navIconGap) {
                Image(systemName: "power")
                    .font(.system(size: SettingsDesign.navIcon))
                    .frame(width: SettingsDesign.navIcon)
                Text("退出 HUD")
                    .font(.system(size: SettingsDesign.navFont))
                Spacer(minLength: 0)
            }
            .foregroundStyle(quitHovered ? HUDDesign.textPrimary : HUDDesign.textTertiary)
            .padding(.horizontal, SettingsDesign.navItemPadH)
            .frame(height: SettingsDesign.navItemH)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: SettingsDesign.navItemRadius))
            .background(
                RoundedRectangle(cornerRadius: SettingsDesign.navItemRadius)
                    .fill(quitHovered ? HUDDesign.hit : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            quitHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: quitHovered)
        .help("退出后管理面板与状态灯都会停止，重新打开应用即可恢复")
    }

    private var versionLine: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Comate HUD \(v) (\(b))"
    }

    private var osLine: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.navItemGap) {
            ForEach(SettingsPage.allCases) { page in
                SettingsNavItem(page: page,
                                isOn: selection.page == page,
                                showDot: showsUpdateDot && page == .general) {
                    selection.page = page
                }
            }
            Spacer(minLength: 0)
            quitItem
            // 底部版本信息：font.meta 9pt + text.quaternary（settings.html .nav .foot）
            VStack(alignment: .leading, spacing: 0) {
                Text(versionLine)
                Text(osLine)
            }
            .font(.system(size: SettingsDesign.navFootFont))
            .foregroundStyle(HUDDesign.textQuaternary)
            .padding(8)
        }
        .padding(.horizontal, SettingsDesign.navPadH)
        .padding(.vertical, SettingsDesign.navPadV)
        .frame(width: SettingsDesign.navWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HUDDesign.raised)
        .overlay(alignment: .trailing) {
            Rectangle().fill(HUDDesign.lineDivider).frame(width: 1)
        }
    }
}

/// 导航项四态（settings.html .ni）：常态 text.secondary + 图标 text.tertiary；
/// hover surface.hit；选中 accent.soft 底 + text.primary(500) + 图标 accent.hover；禁用 text.disabled。
private struct SettingsNavItem: View {
    var page: SettingsPage
    var isOn: Bool
    /// 右侧 5pt 更新红点（稿 .nav-dot，仅「通用」项在检测到新版时亮）
    var showDot: Bool = false
    var action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SettingsDesign.navIconGap) {
                Image(systemName: page.symbol)
                    .font(.system(size: SettingsDesign.navIcon))
                    .frame(width: SettingsDesign.navIcon, height: SettingsDesign.navIcon)
                    .foregroundStyle(isOn ? HUDDesign.accentHover
                                          : (hovered ? HUDDesign.textPrimary : HUDDesign.textTertiary))
                Text(page.label)
                    .font(.system(size: SettingsDesign.navFont, weight: isOn ? .medium : .regular))
                    .foregroundStyle(isOn ? HUDDesign.textPrimary
                                          : (hovered ? HUDDesign.textPrimary : HUDDesign.textSecondary))
                Spacer(minLength: 0)
                if showDot { UpdateDotBadge() }
            }
            .padding(.horizontal, SettingsDesign.navItemPadH)
            .frame(height: SettingsDesign.navItemH)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesign.navItemRadius)
                    .fill(isOn ? HUDDesign.accentSoft : (hovered ? HUDDesign.hit : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: SettingsDesign.navItemRadius))
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

// MARK: - 内容区骨架

/// 右内容区：页内纵向滚动（关于内容自然高 > 可视区，见 settings.html 三）。
private struct SettingsPageBody<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, SettingsDesign.padH)
                .padding(.top, SettingsDesign.padTop)
                .padding(.bottom, SettingsDesign.padBottom)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 页标题 14/600 + 页副标 9pt text.quaternary。
private struct SettingsPageHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: SettingsDesign.pageTitleFont, weight: .semibold))
                .foregroundStyle(HUDDesign.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: SettingsDesign.pageSubFont))
                    .foregroundStyle(HUDDesign.textQuaternary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 分组：标题 12/600 text.secondary（下距 6）+ 卡片（surface.card + line.card + radius.8）。
private struct SettingsGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.groupTitleGap) {
            Text(title)
                .font(.system(size: SettingsDesign.groupTitleFont, weight: .semibold))
                .foregroundStyle(HUDDesign.textSecondary)
            SettingsCard { content }
        }
        .padding(.top, SettingsDesign.groupGap)
    }
}

/// 分组卡片容器
private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius).fill(HUDDesign.card))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
                    .strokeBorder(HUDDesign.lineCard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius))
    }
}

/// 行分隔线：line.divider，占满卡片宽（settings.html `.row + .row{border-top}`）
private struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(HUDDesign.lineDivider).frame(height: 1)
    }
}

// MARK: - 通用行 / 控件

/// 卡片内的一行：`[可选 leading] + 标题(+副标题) + Spacer + [可选 trailing]`。
/// 行高 38（min），行内 6/10，行内块间距 12；带 onTap 时可点并带 hover。
private struct SettingsRow: View {
    var title: String
    var subtitle: String? = nil
    var leading: AnyView? = nil
    var trailing: AnyView? = nil
    var onTap: (() -> Void)? = nil

    @State private var hovered = false

    var body: some View {
        HStack(spacing: SettingsDesign.rowGap) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: SettingsDesign.rowTitleFont))
                    .foregroundStyle(HUDDesign.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: SettingsDesign.rowSubFont))
                        .foregroundStyle(HUDDesign.textQuaternary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, SettingsDesign.rowPadH)
        .padding(.vertical, SettingsDesign.rowPadV)
        .frame(minHeight: SettingsDesign.rowMinH)
        .background(onTap != nil && hovered ? HUDDesign.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onHover { h in
            guard onTap != nil else { return }
            hovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

/// 行右侧只读值：12.5pt text.secondary（settings.html .rv）
private struct SettingsValue: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: SettingsDesign.rowValueFont))
            .foregroundStyle(HUDDesign.textSecondary)
            .lineLimit(1)
    }
}

/// 行尾 chevron：12pt text.quaternary（settings.html .chev）
private struct SettingsChevron: View {
    /// 展开态把 chevron 转成向下（详情展开在行下方）
    var expanded: Bool = false

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: SettingsDesign.chevron))
            .foregroundStyle(HUDDesign.textQuaternary)
            .rotationEffect(.degrees(expanded ? 90 : 0))
    }
}

/// 开关 34×20、钮 16、radius.full：off surface.track / on accent.normal（settings.html .sw）
private struct SettingsSwitch: View {
    var isOn: Bool
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Capsule().fill(isOn ? HUDDesign.accent : HUDDesign.track)
                Circle()
                    .fill(Color.white)
                    .frame(width: SettingsDesign.switchKnob, height: SettingsDesign.switchKnob)
                    .shadow(color: .black.opacity(0.40), radius: 1, y: 1)
                    .offset(x: isOn ? (SettingsDesign.switchW - SettingsDesign.switchKnob - 2) : 2)
            }
            .frame(width: SettingsDesign.switchW, height: SettingsDesign.switchH)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.12), value: isOn)
        .onHover { h in
            guard enabled else { return }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// 单选指示 14pt radius.full：未选中 line.divider-strong 描边 + surface.track 底；
/// 选中 accent 底/描边 + 中心白点（settings.html .rad）
private struct SettingsRadio: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            Circle().fill(isOn ? HUDDesign.accent : HUDDesign.track)
            Circle().strokeBorder(isOn ? HUDDesign.accent : HUDDesign.lineDividerStrong, lineWidth: 1)
            if isOn {
                Circle().fill(Color.white).padding(3.5)
            }
        }
        .frame(width: SettingsDesign.radioSize, height: SettingsDesign.radioSize)
    }
}

/// 按钮三型：主 accent 实底 + 深墨字 + shadow.cta；次 accent.soft 底 + accent.hover 字；
/// 中性 surface.raised + line.divider-strong 描边。统一高 24 / radius.6 / font.btn 12.5/600。
private struct SettingsButton: View {
    enum Kind { case primary, secondary, ghost }

    var title: String
    var icon: String? = nil
    /// 用官方 GitHub 徽标（官网下载页同一份 SVG path）代替 `icon`。
    /// SF Symbols 没有 GitHub 字形，只能自绘（见 `GitHubMark`）
    var gitHubMark: Bool = false
    var kind: Kind = .ghost
    var enabled: Bool = true
    var action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if gitHubMark {
                    GitHubMark().frame(width: 12, height: 12)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 12))
                }
                Text(title)
            }
        }
        .buttonStyle(SettingsButtonStyle(kind: kind, hovered: hovered))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { h in
            guard enabled else { return }
            hovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

private struct SettingsButtonStyle: ButtonStyle {
    var kind: SettingsButton.Kind
    var hovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: SettingsDesign.ctlFont, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(height: SettingsDesign.ctlH)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesign.ctlRadius).fill(background(pressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsDesign.ctlRadius)
                    .strokeBorder(kind == .ghost ? HUDDesign.lineDividerStrong : Color.clear, lineWidth: 1)
            )
            .shadow(color: kind == .primary ? HUDDesign.accent.opacity(0.22) : Color.clear, radius: 9, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: SettingsDesign.ctlRadius))
    }

    private var foreground: Color {
        switch kind {
        case .primary:   return HUDDesign.ink
        case .secondary: return HUDDesign.accentHover
        case .ghost:     return HUDDesign.textPrimary
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary:
            return pressed ? HUDDesign.accentPressed : (hovered ? HUDDesign.accentHover : HUDDesign.accent)
        case .secondary:
            return (hovered || pressed) ? HUDDesign.accentTrack : HUDDesign.accentSoft
        case .ghost:
            return (hovered || pressed) ? HUDDesign.hit : HUDDesign.raised
        }
    }
}

/// 兼容旧的调用名：行内动作按钮即中性按钮
private struct SettingsActionButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        SettingsButton(title: title, kind: .ghost, enabled: enabled, action: action)
    }
}

/// 下拉：高 24 / 最小宽 132 / radius.6 / surface.raised + line.divider-strong / 尾 chevron 10（settings.html .pop）。
/// 用 `Menu` + borderless style 自绘标签，才能拿到稿子的底、描边与尺寸。
private struct SettingsPopup<Value: Hashable>: View {
    var current: Value
    var options: [(String, Value)]
    var onSelect: (Value) -> Void

    @State private var hovered = false

    private var currentLabel: String {
        options.first { $0.1 == current }?.0 ?? ""
    }

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].0) { onSelect(options[i].1) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentLabel)
                    .font(.system(size: SettingsDesign.ctlFont))
                    .foregroundStyle(HUDDesign.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(HUDDesign.textTertiary)
            }
            .padding(.horizontal, 8)
            .frame(minWidth: SettingsDesign.popMinW, minHeight: SettingsDesign.ctlH, maxHeight: SettingsDesign.ctlH)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesign.ctlRadius)
                    .fill(hovered ? HUDDesign.hit : HUDDesign.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsDesign.ctlRadius)
                    .strokeBorder(HUDDesign.lineDividerStrong, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: SettingsDesign.ctlRadius))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { h in
            hovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// 警示条（登录失效）：status.waiting-soft 底 + line.warn 描边 + radius.8，内边距 10/12，
/// 灯 7pt status.waiting + glow（settings.html .warn）
private struct SettingsWarning: View {
    var title: String
    var subtitle: String?
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(HUDDesign.waiting)
                .frame(width: 7, height: 7)
                .shadow(color: HUDDesign.waiting.opacity(0.30), radius: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: SettingsDesign.rowTitleFont))
                    .foregroundStyle(HUDDesign.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: SettingsDesign.rowSubFont))
                        .foregroundStyle(HUDDesign.textQuaternary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            SettingsButton(title: actionTitle, kind: .primary, action: action)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: SettingsDesign.cardRadius).fill(HUDDesign.waitingSoft))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
                .strokeBorder(SettingsDesign.warnLine, lineWidth: 1)
        )
        .padding(.top, SettingsDesign.groupGap)
    }
}

// MARK: - 通用页 · 检查更新（行 + 内联详情）

/// 主页「更新」组的两行合一：**行**（五态，只改图标语义 / 文案 / 右侧控件层级，行高 38）
/// + **详情**（有新版时整行可点展开/收起）。
///
/// 详情原先是独立的「更新提示小窗」（420×320），用户反馈 ⑥：不要弹窗，内容整合到设置窗详情里。
/// 于是窗口与 `UpdateActions` 一并下线，版本迁移 / changelog 三组 / 两个下载入口 / 跳过此版本
/// 全部就地渲染在这张卡里；`UpdatePromptState` 仍作为状态判定的单一来源。
private struct SettingsUpdateSection: View {
    @ObservedObject var store: ComateStore

    @State private var hovered = false
    /// 有新版时详情默认展开：红点把人带进来，到了就该直接看到「什么变了 / 去哪下」
    @State private var detailExpanded = true

    /// 行态：稿里的三态 + 「尚未检查」+ 失败兜底（= 更新小窗四态 + idle）
    private enum RowState { case idle, checking, latest, available, failed }

    /// 状态判定沿用更新小窗的 `resolve`（纯函数，test.sh 直接钉住了优先级）：
    /// 有新版 > 检查中 > 失败 > 已最新。这里只把「从没查过」再细分出 idle ——
    /// 小窗里它与 checking 同一副文案，但设置行的骨架不同（未检查 = 两行 + 按钮）
    private var state: RowState {
        let s = UpdatePromptState.resolve(hasUpdate: store.hasUpdate,
                                          isChecking: store.isCheckingUpdate,
                                          failed: store.updateCheckFailed,
                                          checked: store.updateChecked)
        if s == .checking && !store.updateChecked && !store.isCheckingUpdate { return .idle }
        switch s {
        case .available: return .available
        case .checking:  return .checking
        case .latest:    return .latest
        case .failed:    return .failed
        }
    }

    /// 详情只在「有新版」时存在；行右侧的 chevron 同时兼任展开指示
    private var showsDetail: Bool { state == .available && detailExpanded }

    /// 各态文案（稿：通用页「检查更新」行 + 页末三态小样）
    private var statusText: String {
        switch state {
        case .idle:
            return "手动触发一次版本检查 · 当前 v\(UpdateChecker.localVersion)"
        case .checking:
            return "正在检查更新…"
        case .latest:
            // 稿只写「已是最新版本 vX」；「· N 分钟前」是刻意加的（DESIGN.md §7.6 已登记），
            // 用来回答「上次何时查的」，不改变行的结构
            let version = "已是最新版本 v\(UpdateChecker.localVersion)"
            let ago = UpdateChecker.relativeDescription(since: store.lastUpdateCheckAt)
            return ago.isEmpty ? version : "\(version) · \(ago)"
        case .available:
            return "检测到新版 \(store.availableUpdate ?? "")"
        case .failed:
            return "检查更新失败，可能是网络不通"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if showsDetail { detailBlock.padding(.top, 8) }
        }
    }

    /// 行本体（稿的 38pt 骨架）
    private var row: some View {
        HStack(spacing: 6) {
            // 有新版时文案前多一枚 5pt 红点（稿 .badge）：先红点、再图标、再文案
            if state == .available { UpdateDotBadge() }
            leadingIcon
            label
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, SettingsDesign.rowPadH)
        .padding(.vertical, SettingsDesign.rowPadV)
        .frame(minHeight: SettingsDesign.rowMinH)
        .background(state == .available && hovered ? HUDDesign.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { if state == .available { detailExpanded.toggle() } }
        .onHover { h in
            guard state == .available else { return }
            hovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }

    // MARK: 详情（原「更新提示小窗」的内容，现在就地渲染）

    /// 更新详情卡：版本迁移行 → changelog 三组（新增/优化/修复，空组不占位）
    /// → 两个下载入口 + 跳过此版本。版式沿用 update.html，只是从独立窗口换成行下内联
    private var detailBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            versionTransition
            if !store.availableUpdateNotes.isEmpty {
                let groups = store.availableUpdateNotes.groups
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(groups.indices, id: \.self) { i in
                        noteGroup(title: groups[i].title, items: groups[i].items)
                    }
                }
            } else {
                Text("本次发布未附更新说明，可到发布页查看完整记录。")
                    .font(.system(size: SettingsDesign.rowSubFont))
                    .foregroundStyle(HUDDesign.textQuaternary)
            }
            HStack(spacing: 8) {
                SettingsButton(title: "官网下载", icon: "arrow.down", kind: .primary,
                               action: openWebsite)
                // 用户反馈 ②：参考官网下载页的 GitHub 按钮，直接用官方 octocat 徽标
                // （同一份 SVG path，见 `GitHubMark`；之前那枚 arrow.triangle.branch 只是替代字形）
                SettingsButton(title: "GitHub 下载", gitHubMark: true, kind: .secondary,
                               action: openGitHub)
                Spacer(minLength: 0)
                skipLink
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesign.cardRadius).fill(HUDDesign.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsDesign.cardRadius)
                .strokeBorder(HUDDesign.lineCard, lineWidth: 1)
        )
    }

    /// 版本迁移行：当前 vX → vY（稿 update.html 的 .ver）
    private var versionTransition: some View {
        HStack(spacing: 6) {
            Text("v\(UpdateChecker.localVersion)")
                .foregroundStyle(HUDDesign.textTertiary)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(HUDDesign.textQuaternary)
            Text("v\(store.availableUpdate ?? "")")
                .font(.system(size: SettingsDesign.rowValueFont, weight: .semibold,
                              design: .rounded))
                .foregroundStyle(HUDDesign.accentHover)
        }
        .font(.system(size: SettingsDesign.rowValueFont, weight: .medium, design: .rounded))
    }

    /// 一组 changelog：组名（品牌绿小字）+ 逐条圆点
    private func noteGroup(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: SettingsDesign.rowSubFont, weight: .semibold))
                .foregroundStyle(HUDDesign.accentHover)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(HUDDesign.textQuaternary)
                        .frame(width: 3, height: 3)
                        .padding(.top, 6)
                    Text(item)
                        .font(.system(size: SettingsDesign.rowSubFont))
                        .foregroundStyle(HUDDesign.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var skipLink: some View {
        Button(action: { store.acknowledgeUpdate() }) {
            Text("跳过此版本")
                .font(.system(size: SettingsDesign.rowSubFont))
                .foregroundStyle(HUDDesign.textTertiary)
                // 不用 .underline()：它要 macOS 13；手画一条（与关于页 footerLink 同做法）
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HUDDesign.lineDividerStrong).frame(height: 1)
                }
        }
        .buttonStyle(.plain)
        .help("记下这个版本，不再提示；下次发新版本会重新提醒")
    }

    private func openWebsite() {
        guard let url = URL(string: HUDLinks.website) else { return }
        NSWorkspace.shared.open(url)
    }

    /// 拿不到具体 Release 链接时退回官网（与旧更新窗同一套兵兵）
    private func openGitHub() {
        guard let url = store.availableUpdateURL ?? URL(string: HUDLinks.website) else { return }
        NSWorkspace.shared.open(url)
    }

    private var leadingIcon: some View {
        Group {
            switch state {
            case .idle:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(HUDDesign.textTertiary)
            case .checking:
                // 稿子用中性 5pt 圆点表示「进行中」，不占状态色
                Circle().fill(HUDDesign.textTertiary).frame(width: 5, height: 5)
            case .latest:
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HUDDesign.done)
            case .available:
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(HUDDesign.textTertiary)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14))
                    .foregroundStyle(HUDDesign.waiting)
            }
        }
        .frame(width: 14, height: 14)
    }

    /// 正文：只有「尚未检查」是稿里的两行骨架（标题 13 + 副标 11.5 + 右侧按钮）；
    /// 其余各态收成单行状态文案 —— 稿：三态共用同一行骨架，差异只在图标语义、文案与按钮层级
    @ViewBuilder
    private var label: some View {
        if state == .idle {
            VStack(alignment: .leading, spacing: 2) {
                Text("检查更新")
                    .font(.system(size: SettingsDesign.rowTitleFont))
                    .foregroundStyle(HUDDesign.textPrimary)
                Text(statusText)
                    .font(.system(size: SettingsDesign.rowSubFont))
                    .foregroundStyle(HUDDesign.textQuaternary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(statusText)
                .font(.system(size: SettingsDesign.rowTitleFont,
                              weight: state == .available ? .medium : .regular))
                .foregroundStyle(state == .available ? HUDDesign.accentHover : HUDDesign.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .available:
            // chevron 兼任展开指示：展开时向下（详情在行下方），收起时指右
            SettingsChevron(expanded: detailExpanded)
        case .failed:
            // 稿没有失败态；保留一个重试入口（DESIGN.md §7.6 登记为题外兜底）
            SettingsButton(title: "重试", kind: .ghost) { store.checkForUpdate(force: true) }
        case .idle:
            SettingsButton(title: "检查更新", kind: .ghost) { store.checkForUpdate(force: true) }
        case .checking, .latest:
            // 稿：这两态右侧不放控件（检查中无按钮、已最新无按钮）
            EmptyView()
        }
    }
}

// MARK: - 账号

private struct AccountSettingsPage: View {
    @ObservedObject var store: ComateStore
    /// 用于「打开 WPS Comate」（原右键菜单入口，菜单下线后移到这里）
    var actions: SettingsActions = .inert

    /// 已登录 = 有有效凭据（needsLogin 恰为「无凭据」或「凭据失效」）
    private var isLoggedIn: Bool { !store.needsLogin }

    var body: some View {
        SettingsPageBody {
            SettingsPageHeader(title: "账号", subtitle: "WPS 账号与登录状态")

            // 登录失效：走独立警示条（settings.html 四 · C），不用红色块
            if store.usageState == .authExpired {
                SettingsWarning(title: "登录已失效，重新登录",
                                subtitle: "上次授权已过期，需重新授权才能同步任务",
                                actionTitle: "重新登录") { presentLogin() }
            }

            SettingsGroup(title: "登录信息") {
                if isLoggedIn {
                    SettingsRow(title: "账号", subtitle: accountSubtitle,
                                leading: AnyView(avatar),
                                trailing: AnyView(SettingsValue(text: nickname)))
                    SettingsDivider()
                    SettingsRow(title: "企业",
                                trailing: AnyView(SettingsValue(text: company)))
                    SettingsDivider()
                    openComateRow
                } else {
                    // 登录失效时上方警示条已经给了「重新登录」，这里不再挂第二个登录入口
                    if store.usageState != .authExpired {
                        SettingsRow(title: "WPS 账号", subtitle: loginSubtitle,
                                    trailing: AnyView(SettingsButton(title: loginButtonTitle, kind: .primary) { presentLogin() }))
                        SettingsDivider()
                    }
                    openComateRow
                }
            }

            if isLoggedIn {
                SettingsGroup(title: "操作") {
                    SettingsRow(title: "退出登录", subtitle: "退出后任务列表与额度读数将被清空",
                                leading: AnyView(
                                    Image(systemName: "arrow.right.square")
                                        .font(.system(size: 14))
                                        .foregroundStyle(HUDDesign.textTertiary)
                                ),
                                trailing: AnyView(SettingsChevron()),
                                onTap: { AuthSession.shared.signOut() })
                }
            }
        }
    }

    /// 刻意偏离设计稿：settings.html 的账号页没有这一行。
    /// 原因：原右键菜单的「打开 Comate」入口已随菜单下线，这是「打开 WPS Comate」唯一入口，
    /// 必须保留，放在账号信息分组里（对应契约里 `SettingsActionButton(title: "打开")`）。
    private var openComateRow: some View {
        SettingsRow(title: "打开 WPS Comate", subtitle: "在 Comate 里新建或继续任务",
                    trailing: AnyView(SettingsActionButton(title: "打开") { actions.openComateApp() }))
    }

    /// 账号行头像：28pt radius.full + surface.raised + line.card，缩写 font.label 11/600
    private var avatar: some View {
        ZStack {
            Circle().fill(HUDDesign.raised)
            Circle().strokeBorder(HUDDesign.lineCard, lineWidth: 1)
            if let initial = avatarInitial {
                Text(initial)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HUDDesign.textSecondary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(HUDDesign.textTertiary)
            }
        }
        .frame(width: 28, height: 28)
    }

    /// 账号行副标：稿子示例是「个人版 · 30 天 1,240 / 2,000 点」。
    /// 真实数据里没有套餐名，故用「已用 x / y 点」承载同一信息；取不到就退回登录状态文案。
    private var accountSubtitle: String {
        if store.usageState == .ok, store.activeUsageLimit != nil {
            let readout = store.usageFooterReadout
            return "已用 \(readout.used) / \(readout.total) 点"
        }
        return statusSubtitle
    }

    private var loginSubtitle: String {
        store.usageState == .authExpired
            ? "登录已失效 · 重新授权后可同步任务与额度"
            : "未登录 · 登录后可同步任务与额度"
    }

    private var loginButtonTitle: String {
        store.usageState == .authExpired ? "重新登录" : "登录 WPS 账号…"
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
            SettingsPageHeader(title: "显示", subtitle: "面板形态、聚焦屏幕与记录条数")

            SettingsGroup(title: "显示模式") {
                ForEach(Array(ComateStore.DisplayMode.allCases.enumerated()), id: \.element) { item in
                    if item.offset > 0 { SettingsDivider() }
                    SettingsRow(title: modeTitle(item.element), subtitle: modeHint(item.element),
                                leading: AnyView(SettingsRadio(isOn: store.displayMode == item.element)),
                                onTap: { actions.switchMode(item.element) })
                }
            }

            // 条件：刘海模式且屏幕数 > 1（条件不成立整组不渲染，不留空位）
            if store.displayMode == .notchHUD, screenOptions.count > 1 {
                SettingsGroup(title: "刘海所在屏幕") {
                    SettingsRow(title: "刘海所在屏幕", subtitle: screenHint,
                                trailing: AnyView(screenPopup))
                }
            }

            SettingsGroup(title: "任务记录") {
                SettingsRow(title: "最近记录条数", subtitle: "超出后列表滚动，最大可视高 347pt",
                            trailing: AnyView(limitPopup))
            }

            // 条件：用户自定义过高度（≠ 默认）才出现
            if store.hasCustomExpandedHeight {
                SettingsGroup(title: "面板高度") {
                    SettingsRow(title: "恢复默认高度", subtitle: heightSubtitle,
                                trailing: AnyView(
                                    SettingsButton(title: "恢复默认高度", kind: .secondary) {
                                        store.resetCustomExpandedHeight()
                                    }
                                ))
                }
            }
        }
    }

    /// 选项原文以 settings.html 为准（「刘海模式」「悬浮模式」），
    /// 不复用 store 里的长名「刘海 HUD 模式 / 任意悬浮模式」
    private func modeTitle(_ mode: ComateStore.DisplayMode) -> String {
        switch mode {
        case .notchHUD: return "刘海模式"
        case .floating: return "悬浮模式"
        }
    }

    private func modeHint(_ mode: ComateStore.DisplayMode) -> String {
        switch mode {
        case .notchHUD: return "收起条贴合物理刘海，与开孔无缝"
        case .floating: return "面板悬浮在屏幕顶部，保留 12pt 外边距"
        }
    }

    private var heightSubtitle: String {
        guard let h = store.customExpandedHeight else { return "恢复为按内容自适应" }
        return "当前 \(Int(h.rounded()))pt · 恢复为按内容自适应"
    }

    /// 选中的屏被拔掉时补一句说明（不改行结构）
    private var screenHint: String {
        let base = "多屏时决定收起条挂在哪块屏"
        guard let saved = store.notchScreenID, !screenOptions.contains(where: { $0.id == saved }) else {
            return base
        }
        return base + " · 已选屏幕未连接，当前用主屏幕"
    }

    private var screenPopup: some View {
        SettingsPopup(current: screenTag,
                      options: [("跟随主屏", ScreenTag.follow)]
                          + screenOptions.map { ($0.name, ScreenTag.screen($0.id)) },
                      onSelect: { tag in
                          switch tag {
                          case .follow: actions.selectScreen(nil)
                          case .screen(let id): actions.selectScreen(id)
                          }
                      })
    }

    private var limitPopup: some View {
        SettingsPopup(current: store.recentTaskLimit,
                      options: ComateStore.recentTaskLimitOptions.map { ("最近 \($0) 条", $0) },
                      onSelect: { store.recentTaskLimit = $0 })
    }

    /// 屏幕用 tag 承载（UInt32? 不能直接当 selection）
    private enum ScreenTag: Hashable {
        case follow
        case screen(UInt32)
    }

    private var screenTag: ScreenTag {
        guard let id = store.notchScreenID else { return .follow }
        return .screen(id)
    }

    private var screenOptions: [NotchScreenTarget.Option] { NotchPanel.screenOptions() }
}

// MARK: - 通用

private struct GeneralSettingsPage: View {
    @ObservedObject var store: ComateStore
    var actions: SettingsActions = .inert

    var body: some View {
        SettingsPageBody {
            SettingsPageHeader(title: "通用", subtitle: "启动、更新与后台行为")

            SettingsGroup(title: "启动") {
                SettingsRow(title: "开机自启动",
                            subtitle: "以系统 LaunchAgent 实际状态为准，非本地缓存",
                            trailing: AnyView(
                                SettingsSwitch(isOn: LaunchAtLogin.isEnabled) { toggleLaunchAtLogin() }
                            ))
            }

            SettingsGroup(title: "更新") {
                SettingsUpdateSection(store: store)
            }
        }
    }

    /// 写盘前先确认路径稳定（不稳定就只提示、不写），与菜单同一条约束
    private func toggleLaunchAtLogin() {
        let target = !LaunchAtLogin.isEnabled
        if target, !LaunchAtLogin.isPathStable {
            LaunchAtLogin.warnPathUnstable()
            return
        }
        LaunchAtLogin.setEnabled(target)
        // 开关态直接读 LaunchAgent plist 现算，这里推一次刷新让开关回到真实状态
        store.objectWillChange.send()
    }
}

// MARK: - 关于

/// 原「关于」独立弹窗的内容整体并入此处（弹窗已退场）。
/// 不渲染「检查更新」行：该动作只在通用页的「更新」组出现（避免同一窗口两个入口），
/// 此处只留版本胶囊与官网入口。
private struct AboutSettingsPage: View {
    /// 用于底部「退出 Comate HUD」（原右键菜单入口，菜单下线后移到这里）
    var actions: SettingsActions = .inert

    @State private var ctaHovered = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // 分组节奏：品牌（紧凑）→ 图例（换气）→ 行动（紧凑）→ 署名（收尾）
                // 图标已下线（用户反馈 ③：关于页不要图标），首元素直接是产品名
                Text("Comate HUD")
                    .font(.system(size: SettingsDesign.aboutNameFont, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDDesign.textPrimary)
                    .padding(.top, 10)
                versionChip.padding(.top, 7)
                Text("让 AI 干活，你只管看灯")
                    .font(.system(size: SettingsDesign.aboutTaglineFont, weight: .semibold))
                    .foregroundStyle(HUDDesign.textPrimary)
                    .padding(.top, 16)
                Text("常驻 macOS 刘海区的 Comate 状态指示器。")
                    .font(.system(size: SettingsDesign.aboutDescFont))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(maxWidth: SettingsDesign.aboutDescWidth)
                    .padding(.top, 8)
                statusLegend.padding(.top, 20)
                // 三行特性整并成一行居中（用户反馈 ③：文案简化 + 全部居中对齐）。
                // 原带 ✓ 的三行列表只能左对齐，且与上面的描述重复
                featureLine.padding(.top, 16)
                ctaButton.padding(.top, 16)
                footerLink.padding(.top, 12)
                // 署名移到最底：它是对全页的落款，夹在特性行与主按钮之间会把
                // 「说明 → 行动」这条链路截断
                signedBy.padding(.top, 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SettingsDesign.padH)
            .padding(.top, SettingsDesign.padTop)
            .padding(.bottom, SettingsDesign.padBottom)
            // 图标下线后内容变短，内容区矮于窗口：整块竖向居中，不要让正文都吸在顶部
            .frame(maxWidth: .infinity, minHeight: SettingsDesign.contentHeight, alignment: .center)
            .background(alignment: .top) { brandGlow }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 特性一行：11.5pt text.secondary、居中、可换行
    private var featureLine: some View {
        Text("悬停展开面板 · 进度与额度一体 · 点击直达会话")
            .font(.system(size: 11.5))
            .foregroundStyle(HUDDesign.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 顶部品牌氛围光：整套视觉里唯一保留紫色的地方（T11，唯一例外），只作氛围
    private var brandGlow: some View {
        RadialGradient(colors: [SettingsDesign.glowP1.opacity(0.28),
                                SettingsDesign.glowP2.opacity(0.14),
                                .clear],
                       center: .center, startRadius: 0, endRadius: 190)
            .frame(height: 320)
            .offset(y: -120)
            .allowsHitTesting(false)
    }

    /// 版本胶囊「版本 X.Y.Z」10.5/500，底/描边白 7%、字白 58%（稿 .abv）
    private var versionChip: some View {
        Text("版本 \(shortVersion)")
            .font(.system(size: SettingsDesign.aboutChipFont, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.58))
            .padding(.horizontal, 10)
            .frame(height: 18)
            .background(Capsule().fill(HUDDesign.lineCard))
            .overlay(Capsule().strokeBorder(HUDDesign.lineCard, lineWidth: 1))
    }

    /// 四态图例卡：radius.14 + surface.card
    /// 图例项用面板真身徽标 `LogoMotionBadge`（C 形弧 + 弧内指示），而不是纯色圆点：
    /// 四态在面板里各自带形态与动效（空闲呼吸点+外扩涟漪 / 已完成对勾+迸发星点 /
    /// 工作中三段光轨追逐 / 等待确认感叹号+双圈脉冲），只画一枚同色圆点等于把
    /// 「一眼分辨四态」这个徽标最核心的信息丢掉了。共用同一枚视图后，图例与面板
    /// 不可能再跑偏（含尺寸 28pt、弧结构、动效曲线）。
    private var statusLegend: some View {
        HStack(spacing: 0) {
            legendItem(.gray, "空闲")
            legendItem(.green, "已完成")
            legendItem(.yellow, "工作中")
            legendItem(.red, "等待确认")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: SettingsDesign.legendRadius).fill(HUDDesign.card))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsDesign.legendRadius)
                .strokeBorder(HUDDesign.lineCard, lineWidth: 1)
        )
    }

    /// 图例项。四态都直接复用面板徽标 —— 红灯的 `redBlinking` 默认 true，
    /// 因此「等待确认」自动走 `.waiting`（双圈错相脉冲），与面板一致。
    private func legendItem(_ light: TaskLight, _ label: String) -> some View {
        HStack(spacing: 6) {
            LogoMotionBadge(light: light, size: SettingsDesign.legendBadge)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(HUDDesign.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 署名：10.5pt text.quaternary，强调段 text.strong + accent 下划线
    private var signedBy: Text {
        (Text("通过 ").foregroundColor(HUDDesign.textQuaternary)
         + Text("WPS Comate 应用开发能力 Vibe Coding")
            .fontWeight(.bold)
            .foregroundColor(HUDDesign.textStrong)
            .underline(true, color: HUDDesign.accent)
         + Text(" 打造").foregroundColor(HUDDesign.textQuaternary))
            .font(.system(size: 10.5))
    }

    /// 主按钮「访问官网」150×30 radius.8 品牌绿 + shadow.cta + text.on-accent
    private var ctaButton: some View {
        Button(action: openWebsite) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square").font(.system(size: 12))
                Text("访问官网")
            }
        }
        .buttonStyle(HUDPrimaryButtonStyle(hovered: ctaHovered))
        .onHover { ctaHovered = $0 }
        .help("打开官网，检查更新或提交意见反馈")
    }

    /// 文字链接「检查更新 · 意见反馈 · comate.wpsgo.com」：accent.hover + 品牌绿下划线
    private var footerLink: some View {
        Button(action: openWebsite) {
            Text("检查更新 · 意见反馈 · comate.wpsgo.com")
                .font(.system(size: 10.5))
                .foregroundStyle(HUDDesign.accentHover)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HUDDesign.accent.opacity(0.30)).frame(height: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func openWebsite() {
        guard let url = URL(string: HUDLinks.website) else { return }
        NSWorkspace.shared.open(url)
    }

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

/// 主按钮：品牌绿实底 + 深墨字（白字压绿的对比度只有 ≈1.9:1）
private struct HUDPrimaryButtonStyle: ButtonStyle {
    var hovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(HUDDesign.ink)
            .frame(width: SettingsDesign.aboutCTAWidth, height: SettingsDesign.aboutCTAHeight)
            .background(
                RoundedRectangle(cornerRadius: HUDDesign.radiusLarge)
                    .fill(configuration.isPressed ? HUDDesign.accentPressed
                                                  : (hovered ? HUDDesign.accentHover : HUDDesign.accent))
            )
            .shadow(color: HUDDesign.accent.opacity(configuration.isPressed ? 0.10 : 0.22), radius: 9, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: HUDDesign.radiusLarge))
    }
}
