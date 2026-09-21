import Foundation

/// Comate 网页版用量接口客户端。
///
/// 这两个接口没有公开文档，所以所有失败路径都返回 nil，由调用方降级成占位符——
/// 面板其余功能不受影响，也不会因为接口改版而崩。
/// 凭据是桌面客户端写在 keychain 里的 wps_sid，与浏览器登录状态无关。
enum UsageAPI {

    /// 额度周期
    enum Period: String {
        case daily, monthly

        /// 左下角切换按钮上的短标签
        var shortLabel: String { self == .daily ? "日" : "月" }
    }

    /// 一个周期的额度
    struct Limit {
        let period: Period
        let used: Double
        let total: Double

        var remain: Double { max(0, total - used) }
        /// 已用百分比（0…100）；接口没给总额时按 0 算，避免显示 NaN
        var percent: Double { total > 0 ? min(100, used / total * 100) : 0 }
    }

    struct Limits {
        let daily: Limit?
        let monthly: Limit?

        func limit(_ period: Period) -> Limit? { period == .daily ? daily : monthly }
    }

    /// 一条消耗明细：接口按「请求」返回，同一天同一会话会有多条，需要按会话求和
    struct Record {
        let sessionId: String
        /// 北京时间 yyyyMMdd，用于归日
        let day: String
        let credits: Double
        let tokens: Int
    }

    private static let host = "https://comate.wps.cn"
    /// 与现有「未读消息 / 云端任务」接口保持一致
    private static let referer = "https://comate.wps.cn/web/"
    /// 单页上限：实测传 100 正常返回，传 500 会被服务端压回 20
    private static let pageSize = 100
    /// 翻页上限，防止接口异常时无限翻页
    private static let maxPages = 40

    /// Comate 计费按北京时间，归日和查询区间都固定 +08:00，不依赖本机时区
    static let billingTimeZone = TimeZone(secondsFromGMT: 8 * 3600)!

    private static let billingCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = billingTimeZone
        return calendar
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = billingTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static func isoDayFormatter(_ time: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = billingTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // +08:00 直接写死：接口要的就是这个偏移，跟着本机时区走会跨日错位
        formatter.dateFormat = "yyyy-MM-dd'T'\(time)+08:00"
        return formatter
    }

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - 时间

    /// 北京时间当天（yyyyMMdd）
    static func dayKey(_ date: Date = Date()) -> String { dayKeyFormatter.string(from: date) }

    /// 近 n 天（含今天）的查询区间，北京时间整日
    static func recentRange(days: Int) -> (start: String, end: String) {
        let now = Date()
        let from = billingCalendar.date(byAdding: .day, value: -(days - 1), to: now) ?? now
        return (isoDayFormatter("00:00:00").string(from: from),
                isoDayFormatter("23:59:59").string(from: now))
    }

    // MARK: - 取数

    /// 日/月限额。失败返回 nil。
    static func fetchLimits(sid: String) -> Limits? {
        guard let json = get("/llmproxy/v1/user/token-usage", query: [], sid: sid),
              let data = json["data"] as? [String: Any],
              let usage = data["credits_usage"] as? [String: Any],
              let periods = usage["periods"] as? [[String: Any]] else { return nil }

        var daily: Limit?
        var monthly: Limit?
        for period in periods {
            guard let type = period["period_type"] as? String,
                  let kind = Period(rawValue: type) else { continue }
            let limit = Limit(period: kind,
                              used: number(period["credits_used"]),
                              total: number(period["credits_limit"]))
            if kind == .daily { daily = limit } else { monthly = limit }
        }
        guard daily != nil || monthly != nil else { return nil }
        return Limits(daily: daily, monthly: monthly)
    }

    /// 区间内的消耗明细，自动翻页。
    /// 首页就失败 → nil（调用方保留旧缓存）；后续页失败 → 返回已取到的部分，不整批丢弃。
    static func fetchDetails(sid: String, start: String, end: String) -> [Record]? {
        var records: [Record] = []
        var fetched = 0
        var page = 1

        while page <= maxPages {
            let query = [
                URLQueryItem(name: "model_type", value: "public"),
                URLQueryItem(name: "start_time", value: start),
                URLQueryItem(name: "end_time", value: end),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "page_size", value: "\(pageSize)"),
            ]
            guard let json = get("/api/coserve/v1/usage/details", query: query, sid: sid),
                  let data = json["data"] as? [String: Any],
                  let items = data["items"] as? [[String: Any]] else {
                return records.isEmpty ? nil : records
            }

            for item in items {
                guard let sessionId = item["session_id"] as? String,
                      let timeText = item["time"] as? String,
                      let time = isoParser.date(from: timeText) else { continue }
                records.append(Record(sessionId: sessionId,
                                      day: dayKey(time),
                                      credits: number(item["total_credits"]),
                                      tokens: Int(number(item["total_tokens"]))))
            }
            fetched += items.count
            if items.isEmpty || fetched >= Int(number(data["total"])) { break }
            page += 1
        }
        return records
    }

    /// 按会话汇总智点
    static func creditsBySession(_ records: [Record]) -> [String: Double] {
        records.reduce(into: [:]) { $0[$1.sessionId, default: 0] += $1.credits }
    }

    // MARK: - 展示格式

    /// 智点：小额保留两位（1.68），中额一位（45.6），大额压缩成万/亿
    static func creditsLabel(_ value: Double) -> String {
        if value >= 100_000_000 { return String(format: "%.2f亿", value / 100_000_000) }
        if value >= 10_000 { return String(format: "%.2f万", value / 10_000) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }

    static func percentLabel(_ percent: Double) -> String { String(format: "%.0f%%", percent) }

    // MARK: - 内部

    /// 同步 GET（调用方保证在后台队列）。任何异常都收敛成 nil。
    private static func get(_ path: String, query: [URLQueryItem], sid: String) -> [String: Any]? {
        guard var components = URLComponents(string: host + path) else { return nil }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("wps_sid=\(sid)", forHTTPHeaderField: "Cookie")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let semaphore = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        URLSession.shared.dataTask(with: request) { data, _, _ in
            defer { semaphore.signal() }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["code"] as? Int == 0 else { return }
            result = json
        }.resume()
        _ = semaphore.wait(timeout: .now() + 15)
        return result
    }

    /// JSON 数字可能是 Int / Double / NSNumber，统一转 Double
    private static func number(_ value: Any?) -> Double {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        if let n = value as? NSNumber { return n.doubleValue }
        return 0
    }
}
