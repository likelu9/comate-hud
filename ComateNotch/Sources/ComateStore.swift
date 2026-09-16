import Foundation
import SQLite3
import AppKit

/// 任务状态灯颜色
enum TaskLight: String {
    case gray    // 空闲
    case yellow  // 运行中 / 思考中
    case red     // 等待用户 / 异常 / 错误
    case green   // 已完成

    var color: String {
        switch self {
        case .gray:   return "#8E8E93"
        case .yellow: return "#FFB800"
        case .red:    return "#FF3B30"
        case .green:  return "#34C759"
        }
    }
}

struct ComateTask: Identifiable, Equatable {
    let id: String
    let title: String
    let status: String
    let lastMessageRole: String  // user / assistant
    let messageCount: Int
    let updatedAt: Date
    let sessionFile: String?

    /// 综合判断状态灯（status + lastMessageRole）
    /// - 黄色：运行中/思考中（status=running，或 lastMessageRole=user 表示用户刚发消息 AI 正在处理）
    /// - 绿色：已完成（status=done）
    /// - 灰色：空闲（lastMessageRole=assistant 且 status=idle）
    /// - 红色：等待用户授权/确认/异常（目前数据库无专门字段，暂不触发）
    var light: TaskLight {
        // status=running 或用户刚发消息 → 黄色（思考中）
        if status == "running" || lastMessageRole == "user" {
            return .yellow
        }
        // 已完成 → 绿色
        if status == "done" { return .green }
        // 默认空闲 → 灰色
        return .gray
    }

    var isRunning: Bool { light == .yellow }
    var isCompleted: Bool { status == "done" }

    var statusLabel: String {
        switch light {
        case .yellow: return "思考中"
        case .red:    return "等待回复"
        case .green:  return "已完成"
        case .gray:   return "空闲"
        }
    }
}

final class ComateStore: ObservableObject {
    @Published private(set) var runningTasks: [ComateTask] = []
    @Published private(set) var recentTasks: [ComateTask] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshed: Date = .now

    /// 当前最优先的状态灯（用于收起态显示）
    /// 优先级：红 > 黄 > 绿 > 灰
    /// 与展开态每个任务的 light 使用同一套逻辑，保证一致
    var primaryLight: TaskLight {
        // 1. 红色：有等待用户回复/确认的任务
        if recentTasks.contains(where: { $0.light == .red }) { return .red }
        // 2. 黄色：有运行中/思考中的任务
        if recentTasks.contains(where: { $0.light == .yellow }) { return .yellow }
        // 3. 绿色：有最近完成的任务（5 分钟内）
        let fiveMinAgo = Date().addingTimeInterval(-300)
        if recentTasks.contains(where: { $0.isCompleted && $0.updatedAt > fiveMinAgo }) { return .green }
        // 4. 灰色：全部空闲
        return .gray
    }

    private var timer: Timer?
    private let dbPath: String

    init(dbPath: String? = nil) {
        if let p = dbPath {
            self.dbPath = p
        } else {
            let home = NSHomeDirectory()
            self.dbPath = (home as NSString).appendingPathComponent(".wpscomate/data/chat_history.db")
        }
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    func refresh() {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            DispatchQueue.main.async { self.lastError = "未找到 chat_history.db" }
            return
        }
        var running: [ComateTask] = []
        var recent: [ComateTask] = []
        var error: String?

        DispatchQueue(label: "comatenotch.db").sync {
            var db: OpaquePointer?
            guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                error = "无法打开数据库"; return
            }
            defer { sqlite3_close(db) }

            let sql = """
            SELECT id, title, status, last_message_role, message_count, updated_at_ms, session_file
            FROM chat_sessions ORDER BY updated_at_ms DESC LIMIT 12;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                error = "SQL 预编译失败"; return
            }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id     = String(cString: sqlite3_column_text(stmt, 0))
                let title  = String(cString: sqlite3_column_text(stmt, 1))
                let status = String(cString: sqlite3_column_text(stmt, 2))
                let role   = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let count  = Int(sqlite3_column_int(stmt, 4))
                let ms     = sqlite3_column_int64(stmt, 5)
                let sf     = sqlite3_column_text(stmt, 6)
                let date   = ms > 0 ? Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0) : Date()
                let task = ComateTask(id: id, title: title, status: status,
                                       lastMessageRole: role,
                                       messageCount: count, updatedAt: date,
                                       sessionFile: sf != nil ? String(cString: sf!) : nil)
                if task.isRunning { running.append(task) }
                recent.append(task)
            }
        }

        DispatchQueue.main.async {
            self.lastError = error
            self.runningTasks = running
            self.recentTasks = recent
            self.lastRefreshed = .now
            // 调试：打印第一条任务的状态灯
            if let first = recent.first {
                print("[ComateStore] #1 \(first.title.prefix(15)) status=\(first.status) role=\(first.lastMessageRole) light=\(first.light)")
            }
        }
    }

    // MARK: - 交互

    /// 打开指定会话：拉起 Comate 到前台
    /// Comate 1.5.28 的 deeplink URL 格式未公开且前端未完整实现，
    /// 因此采用可靠方案：用 wpscomate:// scheme 拉起应用 + AppleScript 激活到前台。
    func openSession(_ task: ComateTask) {
        launchComate()
    }

    /// 快速新建任务：拉起 Comate 到前台
    func launchNewSession() {
        launchComate()
    }

    /// 拉起 Comate 应用并激活到前台
    func launchComate() {
        // 1. 先用 URL scheme 唤起（确保应用启动）
        if let url = URL(string: "wpscomate://") {
            NSWorkspace.shared.open(url)
        }
        // 2. 延迟激活到前台（等应用启动/恢复窗口）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let script = "tell application \"WPS Comate\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var err: NSDictionary?
                appleScript.executeAndReturnError(&err)
            }
        }
    }
}
