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
    let messageCount: Int
    let updatedAt: Date
    let sessionFile: String?

    /// 根据 status 映射状态灯
    var light: TaskLight {
        switch status {
        case "running": return .yellow
        case "done":    return .green
        case "idle":    return .gray
        default:        return .gray
        }
    }

    var isRunning: Bool { status == "running" }
    var isCompleted: Bool { status == "done" }

    var statusLabel: String {
        switch status {
        case "running": return "运行中"
        case "done":    return "已完成"
        case "idle":    return "空闲"
        default:        return status
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
    var primaryLight: TaskLight {
        // 1. 红色：有等待用户授权/回复/确认的任务，或异常/错误
        if recentTasks.contains(where: { $0.light == .red }) { return .red }
        // 2. 黄色：有运行中/思考中的任务
        if let t = runningTasks.first { return t.light }
        // 3. 绿色：有已完成的任务（最近 5 分钟内）
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
            SELECT id, title, status, message_count, updated_at_ms, session_file
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
                let count  = Int(sqlite3_column_int(stmt, 3))
                let ms     = sqlite3_column_int64(stmt, 4)
                let sf     = sqlite3_column_text(stmt, 5)
                let date   = ms > 0 ? Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0) : Date()
                let task = ComateTask(id: id, title: title, status: status,
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
        }
    }

    // MARK: - 交互

    func openSession(_ task: ComateTask) {
        if let url = URL(string: "wpscomate://open?session=\(task.id)") {
            NSWorkspace.shared.open(url, configuration: .init()) { _, _ in }
        } else {
            launchComate()
        }
    }

    func launchNewSession() {
        if let url = URL(string: "wpscomate://") {
            NSWorkspace.shared.open(url, configuration: .init()) { _, _ in }
        }
    }

    func launchComate() {
        let bundleID = "cn.wpscomate.comate-agent"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
}
