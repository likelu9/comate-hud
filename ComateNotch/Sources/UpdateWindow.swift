import SwiftUI
import AppKit

// MARK: - 形态

/// 更新提示窗的四种形态（DESIGN.md §7.6 / update.html 的「四态 1:1」）。
enum UpdatePromptState: Equatable {
    case available
    case checking
    case latest
    case failed

    /// 由三个既有标志解析当前该显示哪一态。纯函数，便于 test.sh 直接断言。
    ///
    /// 顺序是有意的：「有新版」优先级最高 —— 已知的新版本不该被一次重新检查的
    /// 中间态盖掉；`checked == false`（从没查成功过）落到「检查中」而不是「已是最新」，
    /// 否则会把「不知道」显示成一个确定的结论。
    static func resolve(hasUpdate: Bool, isChecking: Bool, failed: Bool,
                        checked: Bool) -> UpdatePromptState {
        if hasUpdate { return .available }
        if isChecking { return .checking }
        if failed { return .failed }
        return checked ? .latest : .checking
    }

    /// 窗口标题随形态变（设计稿三态三个标题）
    var windowTitle: String {
        switch self {
        case .available, .checking: return "Comate HUD 有可用更新"
        case .latest: return "Comate HUD 已是最新"
        case .failed: return "Comate HUD · 检查更新失败"
        }
    }
}

/// 更新窗能做的动作。注入而不是直接调 store：窗口与 store 解耦，接线集中在 AppDelegate。
struct UpdateActions {
    var downloadWebsite: () -> Void
    var downloadGitHub: () -> Void
    /// 关窗但保留红点（下次仍提示）
    var later: () -> Void
    /// 记下该版本为已读 → 红点灭
    var skip: () -> Void
    var retry: () -> Void
    var close: () -> Void

    static let inert = UpdateActions(downloadWebsite: {}, downloadGitHub: {}, later: {},
                                     skip: {}, retry: {}, close: {})

    /// 标准接线：两个下载都不 ack（只有「跳过此版本」才 ack）、两个下载都不关窗。
    /// 依据 DESIGN.md §7.6：「跳过」= 记下该版本为已读 → 红点灭；下载只是把用户送到发布页，
    /// 那时他还没有做任何「我处理完了」的声明（浏览器可能根本没开成）。
    static func standard(store: ComateStore) -> UpdateActions {
        UpdateActions(
            downloadWebsite: { open(HUDLinks.website) },
            // 拿不到具体 Release 链接时退回官网
            downloadGitHub: { open(store.availableUpdateURL?.absoluteString ?? HUDLinks.website) },
            later: { UpdateWindowController.shared.close() },
            skip: { store.acknowledgeUpdate(); UpdateWindowController.shared.close() },
            retry: { store.checkForUpdate(force: true) },
            close: { UpdateWindowController.shared.close() })
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}

// MARK: - 窗口

/// 更新提示独立小窗：420 × 320 内容区、不可缩放（DESIGN.md §7.6 / update.html）。
///
/// 为什么不挂在设置窗口里做 sheet：两种模式的 HUD 窗口都是非激活 borderless 面板，
/// 挂不上 SwiftUI sheet（与登录窗、原关于窗、设置窗同一个原因）。
final class UpdateWindowController {
    static let shared = UpdateWindowController()

    private var window: NSWindow?

    private init() {}

    func present(store: ComateStore, actions: UpdateActions) {
        if let window = window {
            // 复用旧窗：形态可能已经变了（上次关窗后后台检查出了结果），标题要重算
            window.title = Self.state(of: store).windowTitle
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = UpdatePromptView(store: store, actions: actions) { [weak self] state in
            // SwiftUI 改不了 NSWindow.title，由视图在形态变化时回调
            self?.window?.title = state.windowTitle
        }
        .environment(\.colorScheme, .dark)

        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = Self.state(of: store).windowTitle
        // 不含 .resizable：窗高由内容（320）定死，缩放会把按钮区推离设计稿基线；
        // 保留最小化（设计稿的红绿灯：关/最小可用、缩放灯灭）
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: UpdateDesign.width, height: UpdateDesign.height))
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    /// 当前形态：与视图同一套判定，避免两处各写一遍
    private static func state(of store: ComateStore) -> UpdatePromptState {
        UpdatePromptState.resolve(hasUpdate: store.hasUpdate,
                                  isChecking: store.isCheckingUpdate,
                                  failed: store.updateCheckFailed,
                                  checked: store.updateChecked)
    }
}

/// 更新窗专用刻度（update.html 的 1:1 值）。颜色取自 `HUDDesign`，不在本文件重复写品牌色。
private enum UpdateDesign {
    static let width: CGFloat = 420
    static let height: CGFloat = 320
    static let padH: CGFloat = 20
    static let padV: CGFloat = 14
    static let iconSize: CGFloat = 56
    static let iconRadius: CGFloat = 12
    static let boxHeight: CGFloat = 100
    static let boxRadius: CGFloat = 8
    /// 成对下载 / 主按钮
    static let buttonHeight: CGFloat = 34
    /// 中性次按钮（稍后 / 好 / 关闭）
    static let secondaryHeight: CGFloat = 30
    static let buttonRadius: CGFloat = 14
    static let gap: CGFloat = 8
}

// MARK: - 内容

private struct UpdatePromptView: View {
    @ObservedObject var store: ComateStore
    let actions: UpdateActions
    var onStateChange: (UpdatePromptState) -> Void = { _ in }

    @State private var spin = false
    /// 系统「减少动态效果」开关：转圈是装饰，不该无视用户的偏好
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: UpdatePromptState {
        UpdatePromptState.resolve(hasUpdate: store.hasUpdate,
                                  isChecking: store.isCheckingUpdate,
                                  failed: store.updateCheckFailed,
                                  checked: store.updateChecked)
    }

    var body: some View {
        VStack(spacing: 0) {
            icon
            versionRow
            notesBox
            Spacer(minLength: 0)
            buttons
        }
        .padding(.horizontal, UpdateDesign.padH)
        .padding(.vertical, UpdateDesign.padV)
        .frame(width: UpdateDesign.width, height: UpdateDesign.height)
        .background(HUDDesign.panel)
        .onAppear {
            onStateChange(state)
            // 落到「没查过」的窗口（今天只有直接打开这条路）就补查一次：别把「不知道」当结论显示
            if !store.hasUpdate && !store.updateChecked { actions.retry() }
        }
        .onChange(of: state) { onStateChange($0) }
    }

    // MARK: 应用图标

    private var icon: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: UpdateDesign.iconSize, height: UpdateDesign.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: UpdateDesign.iconRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: UpdateDesign.iconRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 5)
            // 检查中 / 失败：设计稿画的是压灰的图标（这两态没有「可执行的新版本」）
            .saturation(mutedIcon ? 0 : 1)
            .opacity(mutedIcon ? 0.55 : 1)
    }

    private var mutedIcon: Bool { state == .checking || state == .failed }

    /// 转圈动画：系统开了「减少动态效果」就返回 nil（停在静止弧上）
    private var spinAnimation: Animation? {
        reduceMotion ? nil : .linear(duration: 0.8).repeatForever(autoreverses: false)
    }

    // MARK: 版本行

    @ViewBuilder
    private var versionRow: some View {
        HStack(spacing: 9) {
            switch state {
            case .available:
                monoVersion("v\(UpdateChecker.localVersion)")
                    .foregroundStyle(Color.white.opacity(0.72))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .frame(width: 14, height: 14)
                monoVersion("v\(store.availableUpdate ?? "")")
                    .foregroundStyle(HUDDesign.accentHover)
            default:
                monoVersion("v\(UpdateChecker.localVersion)")
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .frame(height: 18)
        .padding(.top, 8)
    }

    private func monoVersion(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .monospacedDigit()
    }

    // MARK: 说明区块（固定 100pt，四态同高）

    private var notesBox: some View {
        Group {
            switch state {
            case .available: notesList
            case .checking: checkingBody
            case .latest: latestBody
            case .failed: failedBody
            }
        }
        .frame(width: UpdateDesign.width - UpdateDesign.padH * 2,
               height: UpdateDesign.boxHeight)
        .background(RoundedRectangle(cornerRadius: UpdateDesign.boxRadius)
            .fill(state == .failed ? HUDDesign.waiting.opacity(0.14) : Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: UpdateDesign.boxRadius)
            .strokeBorder(state == .failed ? HUDDesign.waiting.opacity(0.32) : Color.white.opacity(0.07),
                          lineWidth: 1))
        .padding(.top, 10)
    }

    /// 有新版：三组圆点列表（新增 / 优化 / 修复），超出就裁掉——
    /// 区块高度是设计稿定死的 100pt，四态按钮基线才对得齐。
    private var notesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.availableUpdateNotes.isEmpty {
                // 兜底：v1.4.3 之前的 Release 正文里没有条目（release.sh 生成 notes 之前发的），
                // 这时把 100pt 空着会像「加载失败」，给一句指向发布页的话。
                Text("本次更新的详细说明请见发布页。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.55))
            } else {
                ForEach(Array(store.availableUpdateNotes.groups.enumerated()), id: \.offset) { index, group in
                    Text(group.title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .padding(.top, index == 0 ? 0 : 5)
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.46))
                                .frame(width: 3, height: 3)
                                .padding(.top, 5)
                            Text(item)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.top, 1)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var checkingBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // 小号内联加载环：轨道 + 25% 品牌绿弧，0.8s 线性无限旋转；
                // 系统开了「减少动态效果」就停在静止弧上（设计稿的可降级约定）
                ZStack {
                    Circle().stroke(Color.white.opacity(0.10), lineWidth: 1.6)
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(HUDDesign.accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(spinAnimation, value: spin)
                }
                .frame(width: 15, height: 15)
                .onAppear { spin = reduceMotion ? false : true }
                Text("正在检查更新…")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            Text("正在从 GitHub Releases 获取最新版本…")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.46))
            skeleton(width: 230)
            skeleton(width: 170)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func skeleton(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.06))
            .frame(width: width, height: 7)
    }

    private var latestBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(HUDDesign.done)
                Text("当前已是最新版本 v\(UpdateChecker.localVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            Text("下次自动检查将在 6 小时内进行")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.46))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HUDDesign.waiting)
                    .padding(.top, 1)
                Text("检查更新失败：无法连接 GitHub Releases")
                    .font(.system(size: 11.5))
                    .foregroundStyle(HUDDesign.waiting)
                    .multilineTextAlignment(.leading)
            }
            Text("可能是网络不通或被限流；更新提醒是增值信息，失败时不打扰主功能，下次仍会自动重试。")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.46))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 按钮区（沉底）

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: UpdateDesign.gap) {
            switch state {
            case .available:
                HStack(spacing: UpdateDesign.gap) {
                    downloadButton("官网下载", icon: "arrow.down",
                                   role: .primary, action: actions.downloadWebsite)
                    downloadButton("GitHub 下载", icon: "arrow.up.right.square",
                                   role: .outline, action: actions.downloadGitHub)
                }
                neutralButton("稍后", action: actions.later)
                skipLink
            case .checking:
                downloadButton("官网下载", icon: "arrow.down",
                               role: .primary, action: actions.downloadWebsite)
                    .disabled(true)
                neutralButton("稍后", action: actions.later)
                skipLink
            case .latest:
                neutralButton("好", action: actions.close)
            case .failed:
                downloadButton("重试", icon: "arrow.clockwise",
                               role: .primary, action: actions.retry)
                neutralButton("关闭", action: actions.close)
            }
        }
        .padding(.top, 10)
    }

    private func downloadButton(_ title: String, icon: String,
                                role: UpdateButtonStyle.Role,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title)
            }
        }
        .buttonStyle(UpdateButtonStyle(role: role))
    }

    private func neutralButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(NeutralButtonStyle())
    }

    private var skipLink: some View {
        Button(action: actions.skip) {
            Text("跳过此版本（不再提示）")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.55))
                // 不用 .underline()：它要 macOS 13；这里手画一条下划线（与关于页同做法）
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 按钮样式

/// 主按钮（品牌绿实底 + 深墨字，34pt）与描边次按钮（同高 34，各占一半）。
private struct UpdateButtonStyle: ButtonStyle {
    enum Role { case primary, outline }

    var role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: UpdateDesign.buttonHeight)
            .background(RoundedRectangle(cornerRadius: UpdateDesign.buttonRadius)
                .fill(background(configuration)))
            .overlay(RoundedRectangle(cornerRadius: UpdateDesign.buttonRadius)
                .strokeBorder(role == .outline ? Color.white.opacity(0.14) : Color.clear,
                              lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: UpdateDesign.buttonRadius))
    }

    @Environment(\.isEnabled) private var isEnabled

    private var foreground: Color {
        switch role {
        case .primary: return isEnabled ? HUDDesign.ink : Color.white.opacity(0.55)
        case .outline: return Color.white.opacity(0.88)
        }
    }

    private func background(_ configuration: Configuration) -> Color {
        switch role {
        case .primary:
            guard isEnabled else { return HUDDesign.accentDisabled }
            return configuration.isPressed ? HUDDesign.accentPressed : HUDDesign.accent
        case .outline:
            return Color.white.opacity(configuration.isPressed ? 0.14 : 0.06)
        }
    }
}

/// 中性次按钮：30pt，白 6% 底 + 8% 描边（稍后 / 好 / 关闭）
private struct NeutralButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .frame(height: UpdateDesign.secondaryHeight)
            .background(RoundedRectangle(cornerRadius: UpdateDesign.buttonRadius)
                .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: UpdateDesign.buttonRadius)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: UpdateDesign.buttonRadius))
    }
}
