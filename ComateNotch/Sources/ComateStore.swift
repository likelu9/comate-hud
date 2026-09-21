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
    /// 任务来源：local=本地(workspace)，cloud=云端托管
    let source: String
    
    /// 是否为云端托管任务
    var isCloud: Bool { source == "cloud" }
    
    /// 来源图标（SF Symbols），对应 Comate 左侧任务列表分组图标
    /// cloud → 云端托管（云图标），local → workspace（文件夹图标）
    var sourceIcon: String {
        isCloud ? "icloud.fill" : "folder.fill"
    }
    
    /// 用于 deeplink 的 id：去掉 woa 任务的 account_id 前缀（如 1388246874-xxx → xxx）
    /// Comate 前端期望标准 UUID，带前缀的 id 会报「找不到该任务」
    var deeplinkId: String {
        // 格式：<数字>-<uuid>，去掉第一个 '-' 及其之前的部分
        if let dashIdx = id.firstIndex(of: "-"),
           let prefix = Int(id[..<dashIdx]),
           prefix > 1000000000 {  // account_id 是 10 位以上数字
            return String(id[id.index(after: dashIdx)...])
        }
        return id
    }
    
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
    /// 云端托管任务列表（从 comate.wps.cn API 获取，不落本地 SQLite）
    @Published private(set) var cloudTasks: [ComateTask] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshed: Date = .now
    @Published private(set) var todayModelUsage: [ModelUsage] = []
    @Published private(set) var attentionCount: Int = 0
    /// 云端消息中心真实未读消息数（从 comate.wps.cn API 获取）
    @Published private(set) var cloudUnreadCount: Int = 0
    /// 正在打开消息中心（用于 UI 显示 loading 提示）
    @Published private(set) var isOpeningMessageCenter: Bool = false

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
        refreshCloudTasks()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.refresh()
        }
        // 云端数据刷新频率较低（30秒），避免频繁请求
        cloudTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshCloudUnread()
            self?.refreshCloudTasks()
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
            SELECT id, title, status, last_message_role, message_count, updated_at_ms, session_file, source
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
                // source 列：app/local 都是本地任务（app=工作目录项目，local=普通本地），
                // 只有来自云端 workmate/sessions/list API 的才是 cloud
                let srcRaw = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? "local"
                let date   = ms > 0 ? Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0) : Date()
                let task = ComateTask(id: id, title: title, status: status,
                                       lastMessageRole: role,
                                       messageCount: count, updatedAt: date,
                                       sessionFile: sf != nil ? String(cString: sf!) : nil,
                                       source: "local")
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
            // 合并本地 + 云端任务，按更新时间降序排序后取前 12 条
            let merged = (recent + self.cloudTasks).sorted { $0.updatedAt > $1.updatedAt }
            self.recentTasks = Array(merged.prefix(12))
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

    /// 从云端 API 获取云端托管任务列表
    /// API: GET https://comate.wps.cn/api/comate/v1/workmate/sessions/list?offset=0&limit=12
    /// 认证: Cookie: wps_sid=<sid>
    /// 云端任务不落本地 SQLite，需单独拉取后与本地任务合并展示
    private func refreshCloudTasks() {
        DispatchQueue.global(qos: .utility).async {
            guard let sid = self.fetchWpsSid() else { return }
            var components = URLComponents(string: "https://comate.wps.cn/api/comate/v1/workmate/sessions/list")!
            components.queryItems = [
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "limit", value: "12")
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
                      json["code"] as? Int == 0,
                      let dataDict = json["data"] as? [String: Any],
                      let sessions = dataDict["sessions"] as? [[String: Any]] else { return }
                let cloudTasks: [ComateTask] = sessions.compactMap { s in
                    guard let id = s["id"] as? String,
                          let title = s["title"] as? String,
                          let status = s["status"] as? String,
                          let updatedStr = s["updated_at"] as? String,
                          let updated = ISO8601DateFormatter().date(from: updatedStr) else { return nil }
                    // 云端 API 无 last_message_role，用 status 推断：running→user，否则 assistant
                    let role = status == "running" ? "user" : "assistant"
                    let count = s["message_count"] as? Int ?? 0
                    return ComateTask(id: id, title: title, status: status,
                                     lastMessageRole: role,
                                     messageCount: count, updatedAt: updated,
                                     sessionFile: nil, source: "cloud")
                }
                DispatchQueue.main.async {
                    self.cloudTasks = cloudTasks
                    // 触发 recentTasks 重新合并（复用 refresh 末尾的合并逻辑）
                    let local = self.recentTasks.filter { !$0.isCloud }
                    let merged = (local + cloudTasks).sorted { $0.updatedAt > $1.updatedAt }
                    self.recentTasks = Array(merged.prefix(12))
                }
            }
            task.resume()
        }
    }
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
        // 云端任务用 cloud deeplink，本地任务用 jointtask deeplink
        // jointtask 格式来自 Comate 自身 jsonl：wpscomate://chat.comate/jointtask?id=<db_id>&ckp=e30=
        // id 用数据库主键（task.id），不是 sessionFile 里的 UUID
        // ckp=e30= 是 base64({})，表示空上下文参数
        let urlString: String
        if task.isCloud {
            urlString = "wpscomate://chat.comate/cloud?id=\(task.id)"
        } else {
            // 本地任务用 jointtask，id 用 deeplinkId（去掉 woa 任务的 account_id 前缀）
            urlString = "wpscomate://chat.comate/jointtask?id=\(task.deeplinkId)&ckp=e30="
        }
        print("[ComateNotch] 打开会话: id=\(task.id), source=\(task.source), url=\(urlString)")
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

    /// 打开 Comate 客户端消息中心：激活 Comate，通过 AX 定位左下角铃铛坐标，用 CGEvent 真实点击。
    /// 异步执行，带 loading 状态（isOpeningMessageCenter）和超时保护。
    func openMessageCenter() {
        guard !isOpeningMessageCenter else { return }
        isOpeningMessageCenter = true
        // 2.5 秒后自动关闭 loading（兜底，防止脚本卡住）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.isOpeningMessageCenter = false
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Step 0: 用 NSWorkspace 激活 Comate（比 AppleScript activate 更可靠）
            // Comate bundle id: cn.wpscomate.comate-agent
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "cn.wpscomate.comate-agent") {
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init(), completionHandler: nil)
            } else {
                // 兜底：按路径打开
                let appPath = "/Applications/WPS Comate.app"
                if FileManager.default.fileExists(atPath: appPath) {
                    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: .init(), completionHandler: nil)
                }
            }
            // 等待 Comate 激活到前台
            Thread.sleep(forTimeInterval: 0.5)

            // Step 1: 通过 AX 定位铃铛 button 的屏幕坐标
            // 铃铛特征：sidebar 底部、AXButton、desc 为空、size 28x28
            // 脚本内先强制 Comate frontmost，确保 AX 能读到 window 1
            let locateScript = """
            tell application "System Events"
                tell process "WPS Comate"
                    try
                        set frontmost to true
                    end try
                end tell
                delay 0.2
                tell process "WPS Comate"
                    tell window 1
                        set wa to UI element 1 of scroll area 1 of group 1 of group 1
                        set sidebar to UI element 4 of wa
                        set allElems to entire contents of sidebar
                        repeat with el in allElems
                            try
                                set r to role of el
                                set d to description of el
                                set s to size of el
                                set sw to (item 1 of s) as integer
                                set sh to (item 2 of s) as integer
                                if r is "AXButton" and d is "" and sw is 28 and sh is 28 then
                                    set p to position of el
                                    set px to (item 1 of p) as integer
                                    set py to (item 2 of p) as integer
                                    return (px as string) & "," & (py as string)
                                end if
                            end try
                        end repeat
                        return "notfound"
                    end tell
                end tell
            end tell
            """
            var error: NSDictionary?
            let result = NSAppleScript(source: locateScript)?.executeAndReturnError(&error).stringValue ?? "notfound"
            if let error = error {
                NSLog("[ComateNotch] openMessageCenter locate error: %@", error)
            }
            guard result != "notfound", !result.isEmpty else {
                NSLog("[ComateNotch] openMessageCenter: bell button not found via AX")
                DispatchQueue.main.async { self?.isOpeningMessageCenter = false }
                return
            }
            // Step 2: 解析坐标，用 CGEvent 真实点击（AX click 对 web 元素不可靠）
            let parts = result.split(separator: ",")
            guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) else {
                NSLog("[ComateNotch] openMessageCenter: invalid coords %@", result)
                DispatchQueue.main.async { self?.isOpeningMessageCenter = false }
                return
            }
            let cx = x + 14  // button 28x28，点击中心点
            let cy = y + 14
            self?.cgEventClick(at: CGPoint(x: cx, y: cy))
            // 留足时间让 Comate 完成页面跳转，再关闭 loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.isOpeningMessageCenter = false
            }
        }
    }

    /// 用 CGEvent 在指定屏幕坐标执行真实鼠标点击（对 web 渲染元素可靠）
    private func cgEventClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(150000)  // 0.15s，让 hover 事件先到达
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(50000)   // 0.05s
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
        NSLog("[ComateNotch] openMessageCenter: CGEvent clicked at (%.0f, %.0f)", point.x, point.y)
    }

    func openComateApp() {
        NSWorkspace.shared.launchApplication("WPS Comate")
    }
}
