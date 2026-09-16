import SwiftUI
import AppKit

struct NotchRootView: View {
    @ObservedObject var store: ComateStore
    @Binding var expanded: Bool
    var onExpandChange: ((Bool) -> Void)?

    @State private var hovering = false
    private let forceExpanded = CommandLine.arguments.contains("--expanded")

    var body: some View {
        ZStack(alignment: .top) {
            // 背板
            RoundedRectangle(cornerRadius: expanded ? 20 : 12, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.45), radius: expanded ? 16 : 4, y: expanded ? 6 : 2)

            content
                .padding(.horizontal, expanded ? 16 : 14)
                .padding(.top, expanded ? 16 : 0)
                .padding(.bottom, expanded ? 14 : 0)
        }
        .frame(width: expanded ? 340 : 280, height: expanded ? 320 : 34)
        .onHover { isHovering in
            hovering = isHovering
            if forceExpanded { return }
            if isHovering {
                expandTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        expanded = true
                    }
                    onExpandChange?(true)
                }
            } else {
                expandTimer?.invalidate()
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                    expanded = false
                }
                onExpandChange?(false)
            }
        }
        .onAppear {
            if forceExpanded {
                expanded = true
                onExpandChange?(true)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if expanded { expandedView } else { collapsedView }
    }

    // MARK: - 收起态：仅刘海高度，左右扩展

    private var collapsedView: some View {
        HStack(spacing: 0) {
            // 左侧：状态指示
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                if let running = store.runningTasks.first {
                    Circle()
                        .fill(Color(hex: running.statusColor))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(hex: running.statusColor).opacity(0.9), radius: 4)
                    Text(truncate(running.title, 12))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("Comate 空闲")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 4)

            // 右侧：新建按钮
            Button(action: { store.launchNewSession() }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text("新建")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 展开态：任务列表

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Comate 任务")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                let count = store.runningTasks.count
                if count > 0 {
                    Text("\(count) 运行中")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.22), in: Capsule())
                        .foregroundStyle(.orange)
                } else {
                    Text("空闲")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Divider().background(Color.white.opacity(0.10))

            // 任务列表
            if store.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(store.recentTasks.prefix(6)) { task in
                            taskRow(task)
                                .onTapGesture { store.openSession(task) }
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() }
                                    else { NSCursor.pop() }
                                }
                        }
                    }
                }
            }

            // Footer
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("实时同步 · \(timeStr(store.lastRefreshed))")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                // 打开 Comate 按钮
                Button(action: { store.launchComate() }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskRow(_ t: ComateTask) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: t.statusColor))
                .frame(width: 7, height: 7)
                .shadow(color: Color(hex: t.statusColor).opacity(0.7), radius: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title.isEmpty ? "（无标题）" : t.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(t.statusLabel)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: t.statusColor))
                    Text("\(t.messageCount) 条消息")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(relTime(t.updatedAt))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
            // 右侧箭头提示可点击
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 动效

    @State private var expandTimer: Timer?

    // MARK: - 工具

    private func truncate(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n - 1)) + "…"
    }
    private func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }
    private func relTime(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "\(s)秒前" }
        if s < 3600 { return "\(s / 60)分钟前" }
        if s < 86400 { return "\(s / 3600)小时前" }
        return "\(s / 86400)天前"
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
