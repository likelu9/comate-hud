import Foundation
import Combine
import SQLite3
import AppKit

/// 一条 Comate 任务（会话）快照
struct ComateTask: Identifiable, Equatable {
    let id: String
    let title: String
    let status: String          // running / idle / done
    let messageCount: Int
    let updatedAt: Date
    let sessionFile: String?    // 可用于打开会话的本地文件路径

    var statusColor: String {
        switch status {
        case "running": return "#FF8A3D"
        case "done":    return "#3DDC84"
        default:        return "#8E8E93"
        }
    }
    var statusLabel: String {
        switch status {
        case "running": return "运行中"
        case "done":    return "已完成"
        case "idle":    return "空闲"
        default:        return status
        }
    }
    var isRunning: Bool { status == "running" }
}

/// 任务进度数据源：读取 ~/.wpscomate/data/chat_history.db
final class ComateStore: ObservableObject {

    @Published private(set) var runningTasks: [ComateTask] = []
    @Published private(set) var recentTasks: [ComateTask] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshed: Date = .now

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

    func stop() {
        timer?.invalidate()
        timer = nil
    }

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
            FROM chat_sessions
            ORDER BY updated_at_ms DESC
            LIMIT 12;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                error = "SQL 预编译失败"; return
            }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id       = String(cString: sqlite3_column_text(stmt, 0))
                let title    = String(cString: sqlite3_column_text(stmt, 1))
                let status   = String(cString: sqlite3_column_text(stmt, 2))
                let count    = sqlite3_column_int(stmt, 3)
                let ms       = sqlite3_column_int64(stmt, 4)
                let sessionF = sqlite3_column_text(stmt, 5)
                let date     = ms > 0 ? Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0) : Date()
                let task = ComateTask(
                    id: id, title: title, status: status,
                    messageCount: Int(count), updatedAt: date,
                    sessionFile: sessionF != nil ? String(cString: sessionF!) : nil
                )
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

    // MARK: - 打开会话

    /// 通过 wpscomate:// URL scheme 打开指定会话
    func openSession(_ task: ComateTask) {
        // 优先尝试 URL scheme
        if let url = URL(string: "wpscomate://open?session=\(task.id)") {
            NSWorkspace.shared.open(url, configuration: .init()) { _, _ in }
            return
        }
        // 降级：启动 Comate 应用
        launchComate()
    }

    /// 打开 Comate 新建会话
    func launchNewSession() {
        if let url = URL(string: "wpscomate://") {
            NSWorkspace.shared.open(url, configuration: .init()) { _, _ in }
        }
    }

    /// 启动 Comate 应用（如果未运行）
    func launchComate() {
        let bundleID = "cn.wpscomate.comate-agent"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }
}
