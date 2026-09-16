import SwiftUI
import AppKit

struct NotchRootView: View {
    @ObservedObject var store: ComateStore
    @State private var expanded = false
    @State private var hovering = false
    private let forceExpanded: Bool = CommandLine.arguments.contains("--expanded")

    var body: some View {
        ZStack(alignment: .top) {
            // 背板：黑色圆角，贴合刘海
            RoundedRectangle(cornerRadius: expanded ? 22 : 18, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.35), radius: expanded ? 14 : 6, y: 4)

            content
                .padding(.horizontal, 14)
                .padding(.top, expanded ? 18 : 8)
                .padding(.bottom, expanded ? 14 : 8)
        }
        .frame(width: expanded ? 360 : 200, height: expanded ? 300 : 34)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: expanded)
        .onHover { hovering = $0
            if forceExpanded { return }
            if $0 { startExpandTimer() } else { expanded = false }
        }
        .onAppear { if forceExpanded { expanded = true } }
    }

    @ViewBuilder private var content: some View {
        if expanded {
            expandedView
        } else {
            collapsedView
        }
    }

    // MARK: - 收起态

    private var collapsedView: some View {
        HStack(spacing: 6) {
            if let t = store.runningTasks.first {
                Circle()
                    .fill(Color(hex: t.statusColor))
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: t.statusColor).opacity(0.9), radius: 4)
                Text("Comate")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(truncate(t.title, 14))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                Circle()
                    .fill(Color(hex: "#3DDC84"))
                    .frame(width: 6, height: 6)
                Text("Comate 空闲")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 展开态

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().background(Color.white.opacity(0.12))
            if store.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(store.recentTasks.prefix(6)) { task in
                            taskRow(task)
                        }
                    }
                }
            }
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Comate 任务进度")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            let running = store.runningTasks.count
            if running > 0 {
                Text("\(running) 运行中")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.22), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.green).frame(width: 5, height: 5)
            Text("实时同步 · \(timeStr(store.lastRefreshed))")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            if store.lastError != nil {
                Text("数据库未连接")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
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
        }
        .padding(.vertical, 2)
    }

    // MARK: - 动效

    @State private var expandTimer: Timer?
    private func startExpandTimer() {
        expandTimer?.invalidate()
        expandTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            withAnimation { expanded = true }
        }
    }

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
        if s < 3600 { return "\(s/60)分钟前" }
        if s < 86400 { return "\(s/3600)小时前" }
        return "\(s/86400)天前"
    }
}

// MARK: - Color hex 扩展

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
