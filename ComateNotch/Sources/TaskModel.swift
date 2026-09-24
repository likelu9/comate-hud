import Foundation

/// 任务模型：从 ComateStore.swift 拆出的纯数据类型。
/// 三者都不依赖 ComateStore（只依赖 Foundation 与 UsageAPI），因此可以整块搬出，
/// 让 ComateStore.swift 只剩状态与数据读取。

/// 任务状态灯颜色
enum TaskLight: String {
    case gray    // 空闲
    case yellow  // 运行中 / 工作中
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
    /// 会话日志末条事件的角色（assistant / toolResult / user）；nil = 没有日志可读
    var lastJournalEventRole: String? = nil
    /// 最近一次观察到「已完成」的时刻（本地库的 status 会被 Comate 改回 idle，
    /// 只看当次 status 会让绿灯提前消失，故记住最后一次看到 done 的时间）
    var doneSeenAt: Date? = nil
    /// 近 30 天智点累计（用量接口按会话汇总；nil = 30 天内没有消耗记录）
    var credits30d: Double? = nil

    /// 是否为云端托管任务
    var isCloud: Bool { source == "cloud" }
    
    /// 来源图标（SF Symbols），对应 Comate 左侧任务列表分组图标
    /// cloud → 云端托管（云图标），local → workspace（文件夹图标）
    var sourceIcon: String {
        isCloud ? "icloud.fill" : "folder.fill"
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
    /// assistant，只看 role 会漏判），要么工具刚回、模型还没落库新消息。
    ///
    /// 最后那条是「工具已回、轮到模型说话」的空档，典型场景就是 auq：你提交回答后
    /// 提问那条 toolCall 已被 toolResult 配对回收，而回答不会把 last_message_role
    /// 顶回 user，只看前两条会误判成已完成→变绿。日志末条是 toolResult 即算在干活。
    ///
    /// 「心跳新鲜」：context_usage.updatedAt 由助手每次模型调用刷新。被强杀 / 中断的轮次
    /// 心跳会停住，没有这道闸，最后一条恰好是 user 消息的会话会永远显示「工作中」。
    var isActive: Bool {
        guard Date().timeIntervalSince(activityAt) < ComateTask.activeWindow else { return false }
        if lastMessageRole == "user" || hasUnfinishedToolCall { return true }
        return lastJournalEventRole == "toolResult"
    }

    /// 心跳新鲜窗口：要能覆盖单次长工具调用（构建 / 测试），又不能长到让死掉的轮次复活
    private static let activeWindow: TimeInterval = 150

    /// 绿灯窗口：任务完成后 15 分钟内保持绿色，之后回落到灰色表示「闲置、可开新任务」
    static let greenWindow: TimeInterval = 900

    /// 综合判断状态灯
    /// 优先级：红（等待确认 / 异常）> 黄（工作中）> 绿（已完成）> 灰（空闲）
    /// 注意本地库里 status=done 不代表「刚完成」——实测轮次进行中同样是 done，
    /// 所以 done 只当「有完成记录」用，真正的「在跑」由 isActive 判定。
    var light: TaskLight {
        // 云端接口没有心跳也没有末条消息，只能信任它返回的 status（实测词表只有 idle/done）
        if isCloud {
            if status == "running" { return .yellow }
            if isCompleted { return .green }
            return .gray
        }
        if redKind != nil { return .red }
        if isActive { return .yellow }
        if isCompleted { return .green }
        return .gray
    }

    var isRunning: Bool { light == .yellow }
    /// 是否算「已完成」：除了当次 status=done，还认 greenWindow 内曾观察到 done。
    /// 本地库的 status 会被 Comate 自己从 done 改回 idle（实测 7 分钟内就回落），
    /// 只信当次 status 会让「完成后保持 15 分钟绿灯」形同虚设。
    var isCompleted: Bool {
        if status == "done" { return true }
        guard let seen = doneSeenAt else { return false }
        return Date().timeIntervalSince(seen) < Self.greenWindow
    }

    var statusLabel: String {
        switch redKind {
        case .waitingConfirmation: return "等待确认"
        case .fault:               return faultReason ?? "异常"
        case nil:                  break
        }
        switch light {
        case .yellow: return "工作中"
        case .red:    return "异常"
        case .green:  return "已完成"
        case .gray:   return "空闲"
        }
    }
}
