import Foundation

/// 读取单条会话的运行日志（`~/.wpscomate/agent/task-sessions/<时间戳>_<uuid>.jsonl`）。
///
/// 这是 Comate Agent SDK 自己落盘的会话流水：每条 assistant 消息带 `usage`（token 用量），
/// 每个工具调用与结果成对出现（`toolCall` / `toolResult`，靠 `toolCallId` 关联），
/// 并且是实时追加的——文件 mtime 始终跟着当前时刻走。相比轮询 SQLite，这里能拿到三样
/// 数据库里没有的东西：
///
/// 1. `askUserQuestion` 的调用/结果配对 → 「正在等你确认」（auq）
/// 2. 每条消息的 `usage` → 累计 token 消耗
/// 3. `errorMessage` / `stopReason` → 报错、被中止、卡住
///
/// 文件可以长到十几 MB，所以首次全量扫一遍（实测 10MB ≈ 76ms），之后记住字节偏移量，
/// 每次只解析新增的行。
final class SessionJournal {
    /// 一条会话日志的累计读数
    struct Reading {
        /// 累计 token 消耗：所有 assistant 消息的 input + output + cacheWrite 之和。
        /// 不含 cacheRead —— 那是同一份上下文被缓存重读，逐轮累加会重复计数
        /// （实测「制作技能」会话：含 cacheRead 是 4.7 万，真实新 token 只有 2.5 万）。
        var consumedTokens = 0
        /// 已发出但还没收到结果的工具调用（id → 工具名 + 发出时刻 + 提问文本）
        /// 时刻先存原字符串，取用时才转 Date：ISO8601 解析很贵，而这里每条工具调用都要存一次
        var pendingToolCalls: [String: (name: String, atText: String, question: String?)] = [:]
        /// 最近一次硬错误；被后续正常收尾清掉（重试成功就不该再算异常）
        var lastError: (atText: String, text: String)?
        /// 日志里最后一条事件的时间与角色
        var lastEventAtText: String?
        var lastEventRole: String?
        /// 最近一次轮次被中止（stopReason=aborted）的时刻；后续有轮次正常收尾就清掉
        var abortedAtText: String?

        var lastEventAt: Date? { SessionJournal.date(from: lastEventAtText) }

        /// 轮次被中止的时刻；nil = 最后一轮正常收尾了。
        ///
        /// 中止和「等你确认」会同时出现：提问发出后你按了停止，提问就永远不会有答案。
        /// 此时该报「已中止」而不是「等待确认」——后者会让人以为还该去回一句话。
        var abortedAt: Date? { SessionJournal.date(from: abortedAtText) }

        /// 正在等你回答的提问时刻（auq）；nil = 没在等
        var pendingAskUserAt: Date? {
            pendingToolCalls.values
                .filter { $0.name == "askUserQuestion" }
                .compactMap { SessionJournal.date(from: $0.atText) }
                .max()
        }

        /// 正在等你回答的那个问题（悬浮窗里显示「在等什么」）
        var pendingAskUserQuestion: String? {
            // 时间戳格式固定且等长，直接按字符串比大小就是按时间比
            pendingToolCalls.values
                .filter { $0.name == "askUserQuestion" }
                .max(by: { $0.atText < $1.atText })?
                .question
        }

        /// 最近一次硬错误的时刻与原因；nil = 没有
        var lastErrorDate: (at: Date, text: String)? {
            guard let error = lastError, let at = SessionJournal.date(from: error.atText) else { return nil }
            return (at, error.text)
        }

        /// 卡住的时刻；nil = 没卡住。
        ///
        /// 判据是「日志静默超过阈值」加上「最后一次动静属于在等别人回话」：
        /// - 有工具调用没回收 → 阈值看工具类型（bash/构建/子 agent 本来就要跑很久）
        /// - 没有未回收的工具 → 最后一条是用户消息或工具结果，说明该模型回话却一直没回
        ///
        /// 正常收尾（stopReason=stop）时最后一条是 assistant 消息，不会误判成卡住。
        var stuckAt: Date? {
            guard let last = lastEventAt else { return nil }
            let silence = Date().timeIntervalSince(last)
            if let oldest = pendingToolCalls.values.min(by: { $0.atText < $1.atText }) {
                return silence > Self.stuckWindow(forTool: oldest.name)
                    ? SessionJournal.date(from: oldest.atText)
                    : nil
            }
            guard lastEventRole == "user" || lastEventRole == "toolResult" else { return nil }
            return silence > Self.stuckWindow(forTool: nil) ? last : nil
        }

        /// 工具调用发出后多久没动静算卡住
        private static func stuckWindow(forTool tool: String?) -> TimeInterval {
            switch tool {
            // 这几类本来就可能跑几分钟（构建、测试、联网、子 agent）
            case "bash", "bg_shell", "subagent", "mcp", "browser_use", "web_search", "view_image":
                return 600
            // 等模型回话，或 read/grep/edit 这类秒回的工具
            default:
                return 120
            }
        }
    }

    private var offset: UInt64 = 0
    private var reading = Reading()

    /// 增量读取。首次调用全量扫描，之后只解析新增的行。
    @discardableResult
    func refresh(path: String) -> Reading {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            // 文件不存在/不可读 → 清空读数，别把上一次的结果当现状
            reading = Reading()
            offset = 0
            return reading
        }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < offset {
            // 文件被截断或重建，重新全扫
            reading = Reading()
            offset = 0
        }
        guard size > offset else { return reading }
        try? handle.seek(toOffset: offset)

        let data = handle.readDataToEndOfFile()
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var lineStart = 0
            for i in 0..<raw.count where raw[i] == 0x0A {
                if i > lineStart {
                    ingest(Data(bytes: base + lineStart, count: i - lineStart))
                }
                lineStart = i + 1
            }
            // 最后一段可能是不完整的半行（还在写），留到下次再解析
            offset += UInt64(lineStart)
        }
        return reading
    }

    private func ingest(_ line: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              obj["type"] as? String == "message",
              let message = obj["message"] as? [String: Any] else { return }

        let atText = obj["timestamp"] as? String ?? ""
        let role = message["role"] as? String ?? ""
        reading.lastEventAtText = atText
        reading.lastEventRole = role

        if role == "assistant" {
            if let usage = message["usage"] as? [String: Any] {
                // 只累加新产生的 token：cacheRead 是同一份上下文被缓存重读，算进去就重复了
                reading.consumedTokens += ["input", "output", "cacheWrite"]
                    .reduce(0) { $0 + (usage[$1] as? Int ?? 0) }
            }
            let stop = message["stopReason"] as? String
            for block in message["content"] as? [[String: Any]] ?? [] {
                guard block["type"] as? String == "toolCall", let id = block["id"] as? String else { continue }
                let name = block["name"] as? String ?? ""
                reading.pendingToolCalls[id] = (name, atText, Self.questionText(of: block, tool: name))
            }
            // 这一轮怎么结束的，决定异常灯亮不亮
            if stop == "stop" {
                reading.lastError = nil
                reading.abortedAtText = nil
            } else if stop == "error" {
                reading.lastError = (atText, "模型返回错误")
            } else if stop == "aborted" {
                // 你按了停止 / 会话被取消：这一轮不会再有下文，挂着的工具调用（包括
                // 提问）都作废，否则会一直报「等待确认」，而其实已经没人会回答它了
                reading.pendingToolCalls.removeAll()
                reading.abortedAtText = atText
            }
        } else if role == "toolResult" {
            if let id = message["toolCallId"] as? String {
                reading.pendingToolCalls.removeValue(forKey: id)
            }
        } else if role == "user" {
            // 你重新发了消息 = 上一轮的中止已经翻篇，灯不该继续停在「已中止」
            reading.abortedAtText = nil
        }

        // errorMessage 比 stopReason 更具体（额度超限 / 连接失败 / 超时…）
        if let error = message["errorMessage"] as? String, let reason = Self.hardErrorReason(error) {
            reading.lastError = (atText, reason)
        }
    }

    /// 把 SDK 的 errorMessage 归类到「需要你处理」的硬错误，返回可展示的短原因；nil = 不算异常。    ///
    /// 「Request was aborted」这类是你自己按了停止，属于正常操作，故意不匹配。
    private static func hardErrorReason(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("rate_limit_exceeded") || text.contains("额度消耗已达到限额") { return "额度已用尽" }
        if text.contains("Connection error") { return "连接失败" }
        if text.contains("timed out") || text.contains("timeout") { return "请求超时" }
        if text.contains("Stream ended without finish_reason") { return "响应中断" }
        if text.contains("thinking budget stopped") { return "思考预算耗尽" }
        if text.contains("模型参数有误") { return "模型参数错误" }
        return nil
    }

    /// 从工具调用参数里取出提问正文（只对 askUserQuestion 有意义）
    private static func questionText(of block: [String: Any], tool: String) -> String? {
        guard tool == "askUserQuestion",
              let args = block["arguments"] as? [String: Any],
              let questions = args["questions"] as? [[String: Any]] else { return nil }
        return questions.first?["text"] as? String
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func date(from text: String?) -> Date? {
        guard let text = text else { return nil }
        return isoFormatter.date(from: text)
    }
}
