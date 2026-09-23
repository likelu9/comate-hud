import AppKit
import SwiftUI

// MARK: - 图标 + 状态灯（刘海模式 / 悬浮模式共用）
// 灯的尺寸与偏移都按 logo 尺寸等比缩放（以 18pt logo 为基准），
// 保证两种模式下灯与图标的相对位置、紧凑度完全一致。

struct HUDLogoBadge: View {
    @ObservedObject var store: ComateStore
    var logoSize: CGFloat
    var lightSize: CGFloat
    var colorful: Bool = true

    @State private var pulseOpacity: Double = 1.0

    private var scale: CGFloat { logoSize / 18 }

    /// 状态灯脉冲：黄灯跳动（工作中），红灯快闪（等你确认）。nil = 常亮
    private var pulse: (duration: Double, low: Double)? {
        if store.primaryLight == .yellow { return (1.2, 0.08) }
        if store.primaryLight == .red && store.primaryRedBlinking { return (0.55, 0.15) }
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
                            .opacity(store.primaryLight != .gray ? 0.45 : 0))
                        .frame(width: lightSize * 2, height: lightSize * 2)
                        .blur(radius: 3 * scale)
                )
                .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
                .shadow(
                    color: store.primaryLight != .gray
                        ? Color(hex: store.primaryLight.color)
                            .opacity(store.primaryLight == .red ? 0.9 : 0.7)
                        : .clear,
                    radius: 4 * scale
                )
                .shadow(
                    color: store.primaryLight != .gray
                        ? Color(hex: store.primaryLight.color)
                            .opacity(store.primaryLight == .red ? 0.6 : 0.4)
                        : .clear,
                    radius: 8 * scale
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

// MARK: - 页脚：额度周期切换 + 消息铃铛（刘海模式 / 悬浮模式共用）

struct HUDUsageFooter: View {
    @ObservedObject var store: ComateStore

    @State private var usageToggleHovered = false
    @State private var bellHovered = false
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
                .padding(.vertical, 4)
                .contentShape(RoundedRectangle(cornerRadius: 5))
                .background(
                    RoundedRectangle(cornerRadius: 5)
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Color.white.opacity(bellHovered ? 0.12 : 0)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
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

struct AboutHUDView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            Text("Comate HUD")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("版本 \(appVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Divider()
            Text("你的 AI 任务状态灯。\n常驻 macOS 刘海区，无需打开主窗口，任务状态一目了然：\n🟢 空闲 · 🟡 工作中 · 🔴 等待确认\n\n悬停刘海即可展开任务面板——最近会话、执行进度、额度用量尽收眼底；点击任务直达对应会话，动态显示 Comate 消息数量。\n\n让 AI 干活，你只管看灯。")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
            Divider()
            Button("好", action: onClose)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 380)
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
