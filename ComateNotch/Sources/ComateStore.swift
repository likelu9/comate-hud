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

/// 红灯的两种成因，决定收起态里红灯能亮多久
enum RedKind: Equatable {
    /// 助手提问后卡住，等你回答（阻塞任务，值得一直提醒）
    case waitingConfirmation
    /// 轮次异常结束（模型不可用 / 连接失败 / 卡住）；你主动按停止不算
    case fault
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

    /// 正在等你确认的时刻（auq）；nil = 没在等
    let waitingSince: Date?
    /// 等待确认的具体问题（悬浮窗里显示「在等什么」）
    let waitingQuestion: String?
    /// 异常时刻与原因（报错 / 卡住）；nil = 正常
    let faultSince: Date?
    let faultReason: String?
    /// 该会话累计 token 消耗（input + output + cacheWrite，不含缓存重读；nil = 没有会话日志可读）
    let consumedTokens: Int?
    /// 是否还有未收尾的工具调用（会话日志里有发出但没结果的调用）
    let hasUnfinishedToolCall: Bool
    /// 最近一次真实活动时间：context_usage.updatedAt（助手每次模型调用都会刷新），兜底 updated_at_ms
    let activityAt: Date
    /// 近 30 天智点累计（用量接口按会话汇总；nil = 30 天内没有消耗记录）
    var credits30d: Double? = nil

    /// 是否为云端托管任务
    var isCloud: Bool { source == "cloud" }
    
    /// 来源图标（SF Symbols），对应 Comate 左侧任务列表分组图标
    /// cloud → 云端托管（云图标），local → workspace（文件夹图标）
    var sourceIcon: String {
        isCloud ? "icloud.fill" : "folder.fill"
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

    /// 行内次要信息：近 30 天智点（与网页「模型用量」同源，按会话汇总）
    /// 30 天内没有消耗记录时给占位符，不硬凑一个「0 点」
    var metaLabel: String {
        guard let credits = credits30d, credits > 0 else { return "—" }
        return "30天 \(UsageAPI.creditsLabel(credits)) 点"
    }

    /// 悬停提示：等确认时优先带出问题，再补用量细节（行里放不下）
    var hoverHelp: String {
        var lines: [String] = []
        if let question = waitingQuestion { lines.append("正在等你回答：\(question)") }
        if let credits = credits30d, credits > 0 {
            lines.append("近 30 天消耗 \(UsageAPI.creditsLabel(credits)) 智点")
        }
        if let tokens = consumedTokens, tokens > 0 {
            lines.append("本机累计 \(ComateTask.tokenLabel(tokens)) tokens")
        }
        if messageCount > 0 { lines.append("\(messageCount) 条消息") }
        return lines.isEmpty ? "在 Comate 中打开该任务" : lines.joined(separator: "\n")
    }

    /// 大数字压缩成好读的形式（1.2万 / 3.45亿）
    private static func tokenLabel(_ n: Int) -> String {
        if n >= 100_000_000 { return String(format: "%.2f亿", Double(n) / 100_000_000) }
        if n >= 10_000 { return String(format: "%.1f万", Double(n) / 10_000) }
        return "\(n)"
    }

    /// 红灯原因（nil = 不红）。两种成因对应两种呈现：等待确认 → 红闪，异常 → 红常亮
    /// - waitingConfirmation：会话日志里有 askUserQuestion 发出但没收到结果（auq）。
    ///   日志是实时追加的，提问和回答的瞬间就能反映出来，不需要时间阈值。
    /// - fault：额度用尽 / 连接失败 / 超时等硬错误，或日志停更超时的「卡住」。
    ///   你主动按停止不属于异常（轮次被中止时挂着的工具调用已作废，不会走到这里）。
    var redKind: RedKind? {
        let now = Date()
        if let at = waitingSince, now.timeIntervalSince(at) < Self.redWindow { return .waitingConfirmation }
        if let at = faultSince, now.timeIntervalSince(at) < Self.redWindow { return .fault }
        return nil
    }

    /// 红灯时效上限：超过这个时长的等待/异常算历史，不再是「现在要你处理」
    private static let redWindow: TimeInterval = 86400

    /// 是否正在干活（黄灯）= 轮次尚未收尾 且 心跳新鲜
    ///
    /// 「轮次尚未收尾」：助手消息只在轮次收尾时落库，所以中途数据库里看不到它。
    /// 此时要么 last_message_role 还是 user（助手一个字都还没落库），要么会话日志里
    /// 留着发出但没结果的工具调用（比如提问落库后 last_message_role 会被顶成
    /// assistant，只看 role 会漏判）。
    ///
    /// 「心跳新鲜」：context_usage.updatedAt 由助手每次模型调用刷新。被强杀 / 中断的轮次
    /// 心跳会停住，没有这道闸，最后一条恰好是 user 消息的会话会永远显示「思考中」。
    var isActive: Bool {
        guard Date().timeIntervalSince(activityAt) < ComateTask.activeWindow else { return false }
        return lastMessageRole == "user" || hasUnfinishedToolCall
    }

    /// 心跳新鲜窗口：要能覆盖单次长工具调用（构建 / 测试），又不能长到让死掉的轮次复活
    private static let activeWindow: TimeInterval = 150

    /// 综合判断状态灯
    /// 优先级：红（等待确认 / 异常）> 黄（思考中）> 绿（已完成）> 灰（空闲）
    /// 注意本地库里 status=done 不代表「刚完成」——实测轮次进行中同样是 done，
    /// 所以 done 只当「有完成记录」用，真正的「在跑」由 isActive 判定。
    var light: TaskLight {
        // 云端接口没有心跳也没有末条消息，只能信任它返回的 status（实测词表只有 idle/done）
        if isCloud {
            if status == "running" { return .yellow }
            if status == "done" { return .green }
            return .gray
        }
        if redKind != nil { return .red }
        if isActive { return .yellow }
        if status == "done" { return .green }
        return .gray
    }

    var isRunning: Bool { light == .yellow }
    var isCompleted: Bool { status == "done" }

    var statusLabel: String {
        switch redKind {
        case .waitingConfirmation: return "等待确认"
        case .fault:               return faultReason ?? "异常"
        case nil:                  break
        }
        switch light {
        case .yellow: return "思考中"
        case .red:    return "异常"
        case .green:  return "已完成"
        case .gray:   return "空闲"
        }
    }
}

final class ComateStore: ObservableObject {
    @Published private(set) var runningTasks: [ComateTask] = []
    @Published private(set) var recentTasks: [ComateTask] = []
    /// 云端托管任务列表（从 comate.wps.cn API 获取，不落本地 SQLite）
    @Published private(set) var cloudTasks: [ComateTask] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshed: Date = .now
    @Published private(set) var attentionCount: Int = 0
    /// 云端消息中心真实未读消息数（从 comate.wps.cn API 获取）
    @Published private(set) var cloudUnreadCount: Int = 0
    /// 正在打开消息中心（用于 UI 显示 loading 提示）
    @Published private(set) var isOpeningMessageCenter: Bool = false
    /// 展开态任务列表展示条数（右键菜单可调：3 / 6 / 10）
    /// 变更即写入 UserDefaults，重启后保持用户选择
    @Published var recentTaskLimit: Int = ComateStore.loadRecentTaskLimit() {
        didSet {
            guard oldValue != recentTaskLimit else { return }
            UserDefaults.standard.set(recentTaskLimit, forKey: ComateStore.recentTaskLimitKey)
        }
    }

    /// 右侧徽章显示的消息数：优先用云端真实未读数，兜底本地近似值
    var totalMessageCount: Int {
        cloudUnreadCount > 0 ? cloudUnreadCount : attentionCount
    }

    /// 当前最优先的状态灯（用于收起态显示）
    /// 优先级：红 > 黄 > 绿 > 灰
    /// 与展开态每个任务的 light 同源，只是红灯额外加时效窗口：展开态回答的是「这个任务什么状态」
    /// （可以一直红），收起态回答的是「现在要不要去看一眼」，陈年未答的提问 / 几天前的失败
    /// 不该让刘海一直亮红。
    var primaryLight: TaskLight {
        let now = Date()
        // 1. 红色：等你确认的提问（任务级已限 24h，它一直阻塞任务）或最近 30 分钟内的异常
        if recentTasks.contains(where: { task in
            switch task.redKind {
            case .waitingConfirmation: return true
            case .fault:               return now.timeIntervalSince(task.faultSince ?? task.updatedAt) < 1800
            case nil:                  return false
            }
        }) { return .red }
        // 2. 黄色：有运行中/思考中的任务
        if recentTasks.contains(where: { $0.light == .yellow }) { return .yellow }
        // 3. 绿色：有最近完成的任务（30 分钟内）
        // 窗口需与详情区 task.light（done 即绿）保持视觉一致：完成后一段时间内顶部也显示绿，
        // 超过窗口才回落到灰色表示"闲置、可开新任务"。5 分钟太短，用户回头查看时已变灰。
        let recentDoneThreshold = Date().addingTimeInterval(-1800)
        if recentTasks.contains(where: { $0.isCompleted && $0.updatedAt > recentDoneThreshold }) { return .green }
        // 4. 灰色：全部空闲
        return .gray
    }

    /// 收起态红灯该不该闪：红是因为「等你确认」（auq），而不是异常。
    /// 与 primaryLight 同源，只是把红灯的两种成因分开——等你确认要闪（得打断你），异常常亮。
    var primaryRedBlinking: Bool {
        recentTasks.contains { $0.redKind == .waitingConfirmation }
    }

    private var timer: Timer?
    private var cloudTimer: Timer?
    private var usageTimer: Timer?
    private let dbPath: String
    /// 动画期间暂停刷新，避免 @Published 更新导致 SwiftUI 重绘竞争
    var isPaused = false

    /// 会话日志读取器缓存（按文件路径）。日志可达十几 MB，靠增量解析把每次轮询压到
    /// 「只读新增的那几 KB」；首次读某个文件会全量扫一遍（实测 10MB ≈ 76ms）。
    /// 只在 refresh 的串行队列里访问，天然无竞争。
    private var journals: [String: SessionJournal] = [:]

    /// 列表条数可选项与持久化 key
    static let recentTaskLimitOptions = [3, 6, 10]
    private static let recentTaskLimitKey = "notch.recentTaskLimit"

    /// 用户拖拽自定义的展开高度（nil = 跟随内容自适应）
    @Published var customExpandedHeight: CGFloat? = ComateStore.loadCustomExpandedHeight()

    /// 是否处于自定义高度（右键菜单据此显示"恢复默认高度"）
    var hasCustomExpandedHeight: Bool { customExpandedHeight != nil }

    /// 拖拽结束才落盘，避免拖拽过程中高频写 UserDefaults
    func saveCustomExpandedHeight(_ h: CGFloat) {
        customExpandedHeight = h
        UserDefaults.standard.set(Double(h), forKey: ComateStore.customHeightKey)
    }

    func resetCustomExpandedHeight() {
        customExpandedHeight = nil
        UserDefaults.standard.removeObject(forKey: ComateStore.customHeightKey)
    }

    private static let customHeightKey = "notch.customExpandedHeight"

    // MARK: - 模型用量

    /// 用量取数状态，决定左下角是显示数字还是「用量 —」
    enum UsageState: Equatable {
        /// 还没取过（启动瞬间）
        case idle
        case ok
        /// keychain 里没有 wps_sid：没装或没登录 Comate 桌面端
        case noCredential
        /// 有凭据但取数失败（网络异常 / sid 失效 / 接口改版）
        case failed
    }

    @Published var usageState: UsageState = .idle

    /// 日/月限额（左下角展示）
    @Published var usageLimits: UsageAPI.Limits?

    /// 近 30 天各会话智点累计（session_id → 点数）。只在主线程读写
    private var credits30d: [String: Double] = [:]

    /// 上次回填 30 天明细的时刻
    private var lastUsageBackfill = Date.distantPast

    /// 上次发起拉取的时刻，用于频次上限
    private var lastUsageFetch = Date.distantPast

    /// 面板是否展开：决定刷新节拍
    private var panelExpanded = false

    /// 频次上限：展开触发与定时节拍共用。反复悬停展开、节拍与展开撞在一起时
    /// 直接跳过，避免连续打接口（最密 30 秒一次）
    static let minFetchInterval: TimeInterval = 30
    /// 展开时节拍：面板可见，保持接近实时
    static let expandedUsageTick: TimeInterval = 60
    /// 收起时兑底节拍：面板不可见，只保证数据不长期陈旧
    static let collapsedUsageTick: TimeInterval = 600
    /// 30 天明细回填间隔（约 5 个请求 / 0.7s）
    static let backfillInterval: TimeInterval = 300

    /// 连续失败次数与下次可重试时间。sid 失效时不至于每个节拍都白打一次接口
    private var usageFailures = 0
    private var usageRetryAfter = Date.distantPast

    /// 退避是否已到期（间隔 60s → 120 → 240 → 300 封顶）
    private var usageRetryAllowed: Bool { Date() >= usageRetryAfter }

    private func noteUsageSuccess() {
        usageFailures = 0
        usageRetryAfter = .distantPast
    }

    private func noteUsageFailure() {
        usageFailures = min(usageFailures + 1, 8)
        let delay = min(60.0 * pow(2, Double(usageFailures - 1)), 300)
        usageRetryAfter = Date().addingTimeInterval(delay)
    }

    /// 用量接口的凭据：桌面客户端登录时写进 keychain 的 wps_sid
    /// （svce=wps365 / acct=credential_wps_sid，不带账号后缀，多账号登录会覆盖成当前账号）。
    /// 与浏览器登录状态无关；与未读消息、云端任务列表两个接口复用同一凭据。
    private var usageCredential: String? { fetchWpsSid() }

    /// 左下角限额显示周期：默认日限额，点击切换月限额，选择持久化
    @Published var usagePeriod: UsageAPI.Period = ComateStore.loadUsagePeriod()

    private static let usagePeriodKey = "notch.usagePeriod"

    private static func loadUsagePeriod() -> UsageAPI.Period {
        UserDefaults.standard.string(forKey: usagePeriodKey)
            .flatMap(UsageAPI.Period.init(rawValue:)) ?? .daily
    }

    func toggleUsagePeriod() {
        usagePeriod = usagePeriod == .daily ? .monthly : .daily
        UserDefaults.standard.set(usagePeriod.rawValue, forKey: ComateStore.usagePeriodKey)
    }

    /// 左下角文案：日/月限额百分比；取不到数据时给占位符
    var usageLimitLabel: String {
        guard usageState == .ok, let limit = usageLimits?.limit(usagePeriod) else { return "用量 —" }
        return "\(usagePeriod.shortLabel) \(UsageAPI.percentLabel(limit.percent))"
    }

    /// 悬停详情：说清「用掉多少 / 还剩多少」，以及为什么没数字
    var usageLimitDetail: String {
        switch usageState {
        case .noCredential:
            return "未登录 Comate 桌面端，读不到用量"
        case .failed:
            return "用量获取失败，稍后自动重试"
        case .idle:
            return "正在获取用量…"
        case .ok:
            guard let limit = usageLimits?.limit(usagePeriod) else { return "暂无用量数据" }
            return "\(limit.period.shortLabel)限额：已用 \(UsageAPI.creditsLabel(limit.used)) / \(UsageAPI.creditsLabel(limit.total)) 智点\n剩余 \(UsageAPI.creditsLabel(limit.remain)) · 点击切换日/月"
        }
    }

    private static func loadCustomExpandedHeight() -> CGFloat? {
        let v = UserDefaults.standard.double(forKey: customHeightKey)
        return v > 0 ? CGFloat(v) : nil
    }

    private static func loadRecentTaskLimit() -> Int {
        let stored = UserDefaults.standard.integer(forKey: recentTaskLimitKey)
        return recentTaskLimitOptions.contains(stored) ? stored : 6
    }

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
        // 模型用量：启动拉一次，之后按面板状态切换节拍（展开 1 分钟 / 收起 10 分钟兑底）
        refreshUsage(trigger: .launch)
        scheduleUsageTimer()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        cloudTimer?.invalidate(); cloudTimer = nil
        usageTimer?.invalidate(); usageTimer = nil
    }

    func refresh() {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            DispatchQueue.main.async { self.lastError = "未找到 chat_history.db" }
            return
        }
        var running: [ComateTask] = []
        var recent: [ComateTask] = []
        var attentionCount = 0
        var error: String?

        DispatchQueue(label: "comatenotch.db").sync {
            var db: OpaquePointer?
            guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                error = "无法打开数据库"; return
            }
            defer { sqlite3_close(db) }

            let sql = """
            SELECT id, title, status, last_message_role, message_count, updated_at_ms,
                   session_file, source, json_extract(context_usage, '$.updatedAt')
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
                let ctxMs  = sqlite3_column_int64(stmt, 8)
                let sessionFile = sf.map { String(cString: $0) }
                // 本地任务统一标记为 local（app/local 来源都是本地，云端任务来自 workmate/sessions/list API）
                let date   = ms > 0 ? Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0) : Date()
                // 心跳优先：context_usage.updatedAt 由助手每次模型调用刷新，updated_at_ms 只在
                // 用户发消息 / 提问落库时被顶，取两者最大值才是「最近真的动过」的时刻
                let heartbeat = ctxMs > 0
                    ? Date(timeIntervalSince1970: TimeInterval(ctxMs) / 1000.0)
                    : Date.distantPast
                let journal = sessionFile.flatMap { readJournal(path: $0) }
                let fault = fault(from: journal)
                let task = ComateTask(id: id, title: title, status: status,
                                       lastMessageRole: role,
                                       messageCount: count, updatedAt: date,
                                       sessionFile: sessionFile,
                                       source: "local",
                                       waitingSince: journal?.pendingAskUserAt,
                                       waitingQuestion: journal?.pendingAskUserQuestion,
                                       faultSince: fault?.0,
                                       faultReason: fault?.1,
                                       consumedTokens: journal?.consumedTokens,
                                       hasUnfinishedToolCall: !(journal?.pendingToolCalls.isEmpty ?? true),
                                       activityAt: max(heartbeat, date))
                if task.isRunning { running.append(task) }
                recent.append(task)
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
            // 贴近 30 天智点：字典在主线程写，这里也在主线程读，无竞争
            self.recentTasks = merged.prefix(12).map { task in
                var copy = task
                copy.credits30d = self.credits30d[task.id]
                return copy
            }
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
        // stderr 不能并入 stdout：否则 security 的警告文本会被当成 sid 发给接口
        task.standardError = FileHandle.nullDevice
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

    /// 读会话日志（增量）。文件不存在或没有事件时返回 nil，调用方据此退回数据库判据
    private func readJournal(path: String) -> SessionJournal.Reading? {
        let journal = journals[path] ?? {
            let created = SessionJournal()
            journals[path] = created
            return created
        }()
        let reading = journal.refresh(path: path)
        return reading.lastEventAt == nil ? nil : reading
    }

    /// 把会话日志读数折成「异常时刻 + 原因」。卡住优先于报错：卡住说的是此刻的状态，
    /// 报错是上一轮的结论（可能已经被后续重试覆盖）。
    private func fault(from reading: SessionJournal.Reading?) -> (Date, String)? {
        guard let reading = reading else { return nil }
        // 顺序即优先级：硬错误最具体，卡住最实时
        if let error = reading.lastErrorDate { return (error.at, error.text) }
        if let stuckAt = reading.stuckAt { return (stuckAt, "卡住无响应") }
        return nil
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
                    // 云端接口不返回 last_message_role，也没有心跳和会话日志，
                    // 除 status 外的判据一律留空（light 里对云端只认 status）
                    let count = s["message_count"] as? Int ?? 0
                    return ComateTask(id: id, title: title, status: status,
                                     lastMessageRole: "",
                                     messageCount: count, updatedAt: updated,
                                     sessionFile: nil, source: "cloud",
                                     waitingSince: nil,
                                     waitingQuestion: nil,
                                     faultSince: nil,
                                     faultReason: nil,
                                     consumedTokens: nil,
                                     hasUnfinishedToolCall: false,
                                     activityAt: updated)
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
    /// 面板展开状态变化：展开时立刻拉一次（受频次上限约束），并切换刷新节拍。
    /// 由 NotchRootView 的 onExpandChange 调用。
    func setPanelExpanded(_ expanded: Bool) {
        guard panelExpanded != expanded else { return }
        panelExpanded = expanded
        scheduleUsageTimer()
        if expanded { refreshUsage(trigger: .expand) }
    }

    private func scheduleUsageTimer() {
        usageTimer?.invalidate()
        usageTimer = Timer.scheduledTimer(
            withTimeInterval: Self.usageTickInterval(expanded: panelExpanded),
            repeats: true
        ) { [weak self] _ in
            self?.refreshUsage(trigger: .timer)
        }
    }

    enum UsageTrigger { case launch, expand, timer }

    /// 节拍间隔：展开时接近实时，收起时 10 分钟兑底
    static func usageTickInterval(expanded: Bool) -> TimeInterval {
        expanded ? expandedUsageTick : collapsedUsageTick
    }

    /// 频次上限：距上次拉取不足 minFetchInterval 就跳过
    static func shouldFetch(lastFetch: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastFetch) >= minFetchInterval
    }

    /// 是否连 30 天明细一起拉：展开/启动时一律拉（打开面板就看到最新点数），
    /// 定时节拍里按 backfillInterval 节流
    static func shouldBackfill(_ trigger: UsageTrigger, lastBackfill: Date, now: Date) -> Bool {
        trigger != .timer || now.timeIntervalSince(lastBackfill) > backfillInterval
    }

    /// 拉取模型用量：限额每个节拍都拉；近 30 天智点明细按 backfillInterval 节流
    /// （实测 462 条 / 5 个请求 / 0.7s）。
    /// 失败不抛错：状态置 failed 并退避，面板显示「用量 —」，其余功能不受影响。
    private func refreshUsage(trigger: UsageTrigger) {
        let now = Date()
        guard Self.shouldFetch(lastFetch: lastUsageFetch, now: now) else { return }
        lastUsageFetch = now
        guard usageRetryAllowed else { return }
        guard let sid = usageCredential else {
            usageState = .noCredential
            return
        }
        let backfill = Self.shouldBackfill(trigger, lastBackfill: lastUsageBackfill, now: now)
        NSLog("[ComateNotch] 拉取用量: trigger=%@, backfill=%@", "\(trigger)", backfill ? "true" : "false")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let limits = UsageAPI.fetchLimits(sid: sid)
            var credits: [String: Double]?
            if backfill {
                let range = UsageAPI.recentRange(days: 30)
                if let records = UsageAPI.fetchDetails(sid: sid, start: range.start, end: range.end) {
                    credits = UsageAPI.creditsBySession(records)
                }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let limits = limits { self.usageLimits = limits }
                if let credits = credits {
                    self.credits30d = credits
                    self.lastUsageBackfill = Date()
                }
                // 明细失败不清空旧值：宁可显示上一次的结果，也不要凭空变空
                if limits != nil || credits != nil {
                    self.usageState = .ok
                    self.noteUsageSuccess()
                } else {
                    self.usageState = .failed
                    self.noteUsageFailure()
                }
            }
        }
    }

    // MARK: - 交互

    /// 打开指定会话：通过 deeplink 跳转到对应会话
    /// 云端任务：wpscomate://chat.comate/cloud?id=<id>
    /// 本地任务：wpscomate://chat.comate/local?id=<db_id>（db_id 含 account_id 前缀，如 1388246874-<uuid>）
    func openSession(_ task: ComateTask) {
        let urlString: String
        if task.isCloud {
            urlString = "wpscomate://chat.comate/cloud?id=\(task.id)"
        } else {
            // 本地任务用 local deeplink，id 用数据库主键（含 account_id 前缀）
            urlString = "wpscomate://chat.comate/local?id=\(task.id)"
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
