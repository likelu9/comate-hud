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
    
    /// 从 sessionFile 中提取 UUID（Comate 应用期望的 task_id）
    var sessionId: String? {
        guard let path = sessionFile else { return nil }
        // 文件名格式: 2026-03-30T03-58-28-613Z_6772c9c6-e5d0-49b0-a7da-ccd1fd1a6462.jsonl
        let filename = (path as NSString).lastPathComponent
        guard let underscoreRange = filename.range(of: "_", options: .backwards) else { return nil }
        let uuidPart = String(filename[underscoreRange.upperBound...])
        let uuid = uuidPart.replacingOccurrences(of: ".jsonl", with: "")
        return uuid.isEmpty ? nil : uuid
    }

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

/// 今日模型用量（按模型分组统计 assistant 消息数）
struct ModelUsage: Identifiable, Equatable {
    let id: String        // model_name
    let name: String      // 显示名
    let count: Int        // 消息数
    var ratio: Double     // 占比 0~1
}

final class ComateStore: ObservableObject {
    @Published private(set) var runningTasks: [ComateTask] = []
    @Published private(set) var recentTasks: [ComateTask] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshed: Date = .now
    @Published private(set) var todayModelUsage: [ModelUsage] = []
    @Published private(set) var attentionCount: Int = 0
    /// 云端消息中心真实未读消息数（从 comate.wps.cn API 获取）
    @Published private(set) var cloudUnreadCount: Int = 0

    /// 今日 assistant 消息总数（所有模型合计）
    var todayTotalMessages: Int {
        todayModelUsage.reduce(0) { $0 + $1.count }
    }

    /// 右侧徽章显示的消息数：优先用云端真实未读数，兜底本地近似值
    var totalMessageCount: Int {
        cloudUnreadCount > 0 ? cloudUnreadCount : attentionCount
    }

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
    private var cloudTimer: Timer?
    private let dbPath: String
    /// 动画期间暂停刷新，避免 @Published 更新导致 SwiftUI 重绘竞争
    var isPaused = false

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
        refreshCloudUnread()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.refresh()
        }
        // 云端未读数刷新频率较低（30秒），避免频繁请求
        cloudTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshCloudUnread()
        }
    }

    func stop() { timer?.invalidate(); timer = nil; cloudTimer?.invalidate(); cloudTimer = nil }

    func refresh() {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            DispatchQueue.main.async { self.lastError = "未找到 chat_history.db" }
            return
        }
        var running: [ComateTask] = []
        var recent: [ComateTask] = []
        var usage: [ModelUsage] = []
        var attentionCount = 0
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

            // 查询今日模型用量（按 model_name 分组统计 assistant 消息数）
            let usageSQL = """
            SELECT model_name, COUNT(*) as cnt
            FROM chat_messages
            WHERE role = 'assistant'
              AND model_name IS NOT NULL
              AND model_name != ''
              AND created_at_ms > (strftime('%s','now','start of day') * 1000)
            GROUP BY model_name
            ORDER BY cnt DESC;
            """
            var uStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, usageSQL, -1, &uStmt, nil) == SQLITE_OK {
                var raw: [(String, Int)] = []
                while sqlite3_step(uStmt) == SQLITE_ROW {
                    let m = String(cString: sqlite3_column_text(uStmt, 0))
                    let c = Int(sqlite3_column_int(uStmt, 1))
                    raw.append((m, c))
                }
                let total = raw.reduce(0) { $0 + $1.1 }
                if total > 0 {
                    usage = raw.map { (m, c) in
                        ModelUsage(id: m, name: displayName(m), count: c, ratio: Double(c) / Double(total))
                    }
                }
                sqlite3_finalize(uStmt)
            }

            // 查询需要关注的会话数（近似"未读消息"）
            // 定义：status=idle + last_message_role=assistant + 最近 7 天
            let attSQL = """
            SELECT COUNT(*) FROM chat_sessions
            WHERE status='idle' AND last_message_role='assistant'
            AND updated_at_ms > (strftime('%s','now')*1000 - 604800000);
            """
            var aStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, attSQL, -1, &aStmt, nil) == SQLITE_OK {
                if sqlite3_step(aStmt) == SQLITE_ROW {
                    attentionCount = Int(sqlite3_column_int(aStmt, 0))
                }
                sqlite3_finalize(aStmt)
            }
        }

        DispatchQueue.main.async {
            self.lastError = error
            self.runningTasks = running
            self.recentTasks = recent
            self.todayModelUsage = usage
            self.attentionCount = attentionCount
            self.lastRefreshed = .now
        }
    }

    /// 从 macOS Keychain 获取 Comate 的 wps_sid
    /// Comate (Tauri 应用) 通过 KSO Account SDK 将 sid 存入 Keychain
    /// service=wps365, account=credential_wps_sid
    /// 值格式为 "go-keyring-base64:<base64>"，解码后得到真实 sid
    private func fetchWpsSid() -> String? {
        // security find-generic-password -a "credential_wps_sid" -w
        let task = Process()
        task.launchPath = "/usr/bin/security"
        task.arguments = ["find-generic-password", "-a", "credential_wps_sid", "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let raw = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: raw, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // 格式: go-keyring-base64:<base64>
            if output.hasPrefix("go-keyring-base64:") {
                let b64 = String(output.dropFirst("go-keyring-base64:".count))
                if let data = Data(base64Encoded: b64) {
                    return String(data: data, encoding: .utf8)
                }
            }
            return output.isEmpty ? nil : output
        } catch {
            return nil
        }
    }

    /// 从云端消息中心 API 获取真实未读消息数
    /// API: GET https://comate.wps.cn/api/coserve/v1/messages?offset=0&limit=100&status=unread
    /// 认证: Cookie: wps_sid=<sid>
    private func refreshCloudUnread() {
        DispatchQueue.global(qos: .utility).async {
            guard let sid = self.fetchWpsSid() else { return }
            var components = URLComponents(string: "https://comate.wps.cn/api/coserve/v1/messages")!
            components.queryItems = [
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "status", value: "unread")
            ]
            guard let url = components.url else { return }
            var req = URLRequest(url: url)
            req.setValue("wps_sid=\(sid)", forHTTPHeaderField: "Cookie")
            req.setValue("https://comate.wps.cn/web/cloud/", forHTTPHeaderField: "Referer")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 8
            let task = URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["code"] as? Int == 0 else { return }
                if let dataDict = json["data"] as? [String: Any],
                   let msgs = dataDict["msgs"] as? [Any] {
                    let count = msgs.count
                    DispatchQueue.main.async {
                        self.cloudUnreadCount = count
                    }
                }
            }
            task.resume()
        }
    }

    /// 模型名简化显示
    private func displayName(_ model: String) -> String {
        let lower = model.lowercased()
        if lower.hasPrefix("glm") { return "GLM" }
        if lower.hasPrefix("mimo") { return "MiMo" }
        if lower.hasPrefix("deepseek") { return "DeepSeek" }
        if lower.hasPrefix("qwen") { return "Qwen" }
        if lower.hasPrefix("claude") { return "Claude" }
        if lower.hasPrefix("gpt") { return "GPT" }
        return model
    }

    // MARK: - 交互

    /// 打开指定会话：通过 deeplink 跳转到对应会话
    /// 格式：wpscomate://chat.comate/jointtask?id=<session_uuid>&ckp=<base64({})>
    /// id 为会话 UUID（从 sessionFile 提取），ckp 为 base64 编码的参数对象（空对象即可）
    func openSession(_ task: ComateTask) {
        let urlString = "wpscomate://chat.comate/local?id=\(task.id)"
        print("[ComateNotch] 打开会话: id=\(task.id), url=\(urlString)")
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// 拉起 Comate 应用并激活到前台（fallback）
    func launchComate() {
        if let url = URL(string: "wpscomate://") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开 Comate 新建本地任务页面
    func openNewTask() {
        if let url = URL(string: "wpscomate://chat.comate/new") {
            NSWorkspace.shared.open(url)
        }
    }

    func openComateApp() {
        NSWorkspace.shared.launchApplication("WPS Comate")
    }
}
