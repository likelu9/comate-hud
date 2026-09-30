import Foundation

/// 语义化版本比较。纯函数、无副作用，便于 test.sh 直接编译验证。
enum HUDVersion {
    /// 把 "v1.4.10-beta.1" 解析为 [1, 4, 10]。
    /// 只取主版本号段：遇到第一个非数字/点字符即截断，因此 -beta / +build 等后缀不参与比较。
    static func segments(_ raw: String) -> [Int] {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let core = s.prefix { $0.isNumber || $0 == "." }
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// remote 是否比 local 新。段数不足的一方补 0，因此 1.4 == 1.4.0，1.10 > 1.9。
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = segments(remote)
        let l = segments(local)
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}

/// 更新说明：按设计稿 §7.6 的三组归类。
///
/// 数据源是 **Release 正文**（`releases.atom` 里那条 entry 的 `<content>`）：
/// `release.sh` 生成正文时就是从 `versions.json` 的 changelog 一条条映射成
/// 「✨ 新增 / ⚡ 优化 / 🔧 修复」前缀的，两边同一套 type 标签，内容等价。
/// 不单独去拉官网那份 `versions.json`：它挂在 `/s/HyDSehobOTHX/` 下，
/// 需要 WPS 会话（未登录客户端实测 403 access_denied），客户端根本拉不到；
/// 走 feed 也顺带免掉了「本地提交未推送时 raw 地址还停在旧版」的鲜度问题。
struct UpdateNotes: Equatable {
    var added: [String] = []
    var improved: [String] = []
    var fixed: [String] = []

    var isEmpty: Bool { added.isEmpty && improved.isEmpty && fixed.isEmpty }

    /// 按设计稿顺序（新增 → 优化 → 修复）给出**非空**组，供窗口逐组渲染：
    /// 空组不占位，否则 100pt 高的说明区会被空标题吃掉大半。
    var groups: [(title: String, items: [String])] {
        [("新增", added), ("优化", improved), ("修复", fixed)].filter { !$0.1.isEmpty }
    }
}

/// 更新状态的四种形态。
///
/// 原先只服务于「更新提示小窗」的标题与版面；小窗下线（内容搬进设置窗通用页详情）后，
/// 它仍然是状态判定的单一来源 —— 设置行的五态 = 这四态 + 「尚未检查」，
/// 优先级也在这里一处定死。纯函数，便于 test.sh 直接断言。
enum UpdatePromptState: Equatable {
    case available
    case checking
    case latest
    case failed

    /// 顺序是有意的：「有新版」优先级最高 —— 已知的新版本不该被一次重新检查的
    /// 中间态盖掉；`checked == false`（从没查成功过）落到「检查中」而不是「已是最新」，
    /// 否则会把「不知道」显示成一个确定的结论。
    static func resolve(hasUpdate: Bool, isChecking: Bool, failed: Bool,
                        checked: Bool) -> UpdatePromptState {
        if hasUpdate { return .available }
        if isChecking { return .checking }
        if failed { return .failed }
        return checked ? .latest : .checking
    }
}

/// 三组说明的语义标签。只认设计稿这三组。
enum UpdateNoteGroup: String, CaseIterable {
    case added, improved, fixed

    var label: String {
        switch self {
        case .added: return "新增"
        case .improved: return "优化"
        case .fixed: return "修复"
        }
    }
}

/// 更新检测：读 GitHub Releases 的最新 tag，与本地 CFBundleShortVersionString 比对。
///
/// 用 releases.atom 而不是 REST API：REST 未鉴权限额按 **IP** 计（60 次/时），
/// 在共享出口 IP（公司网络 / 代理）下实测会直接 403；atom feed 同源公开、无此限额。
/// 任何失败都静默返回 nil —— 更新提醒是增值信息，不该干扰任务状态这类主功能。
final class UpdateChecker {
    struct Release {
        /// tag 名，如 "v1.4.2"
        let version: String
        /// 发布页（GitHub Release，公开可访问）
        let url: URL?
        /// 该版本的更新说明（从 Release 正文解析，见 `UpdateNotes`）
        let notes: UpdateNotes
    }

    static let shared = UpdateChecker()
    static let feedURL = URL(string: "https://github.com/likelu9/comate-hud/releases.atom")!

    /// 本地版本号，来源 Info.plist（版本号的唯一真源）
    static var localVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// 从 feed 文本里取最新一条 release。纯函数，便于 test.sh 直接验证。
    static func parseLatest(feed: String) -> Release? {
        // feed 按时间倒序，第一条 entry 即最新
        guard let entryStart = feed.range(of: "<entry>"),
              let entryEnd = feed.range(of: "</entry>", range: entryStart.upperBound..<feed.endIndex)
        else { return nil }
        let entry = String(feed[entryStart.upperBound..<entryEnd.lowerBound])

        // 优先从 releases/tag/<tag> 取版本，取不到再退回标题里的版本号
        let href = firstMatch(in: entry, pattern: "href=\"([^\"]*releases/tag/[^\"]+)\"")
        let tag = firstMatch(in: entry, pattern: "releases/tag/([^\"]+)\"")
        let title = firstMatch(in: entry, pattern: "<title>([^<]*)</title>")
        let version = [tag, title]
            .compactMap { $0 }
            .compactMap { firstMatch(in: $0, pattern: "([0-9]+(?:\\.[0-9]+)+)") }
            .first
        guard let version = version else { return nil }
        return Release(version: version,
                       url: href.flatMap(URL.init(string:)),
                       notes: parseNotes(fromEntry: entry))
    }

    /// 从一条 entry 里解析更新说明。纯函数，便于 test.sh 直接验证。
    static func parseNotes(fromEntry entry: String) -> UpdateNotes {
        guard let raw = firstMatch(in: entry,
                                   pattern: "<content[^>]*>(.*?)</content>",
                                   options: [.dotMatchesLineSeparators]) else {
            return UpdateNotes()
        }
        let html = unescape(raw)
        guard let re = try? NSRegularExpression(pattern: "<li>(.*?)</li>",
                                                options: [.dotMatchesLineSeparators]) else {
            return UpdateNotes()
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var notes = UpdateNotes()
        for match in re.matches(in: html, range: range) {
            guard let r = Range(match.range(at: 1), in: html) else { continue }
            // 两层实体：XML 一层（上面 unescape 解掉）+ 正文自身那层 HTML（这里解掉）
            guard let line = classifyNoteLine(unescape(stripTags(String(html[r])))) else { continue }
            switch line.group {
            case .added: notes.added.append(line.text)
            case .improved: notes.improved.append(line.text)
            case .fixed: notes.fixed.append(line.text)
            }
        }
        return notes
    }

    /// 一行说明归组。前缀由 `release.sh` 生成、固定在行首（emoji 之后），如「🔧 修复 <文案>」，
    /// 因此只认行首 4 个字符以内出现的中文标签 —— 正文里再出现「修复」二字不会被误判。
    /// 只认设计稿的三组；将来若多出别的 type（如官网的「架构」）一律跳过，不猜。
    static func classifyNoteLine(_ line: String) -> (group: UpdateNoteGroup, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for candidate in UpdateNoteGroup.allCases {
            guard let r = trimmed.range(of: candidate.label),
                  trimmed.distance(from: trimmed.startIndex, to: r.lowerBound) <= 4 else { continue }
            let text = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : (candidate, text)
        }
        return nil
    }

    private static func stripTags(_ html: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "<[^>]*>") else { return html }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return re.stringByReplacingMatches(in: html, range: range, withTemplate: "")
    }

    /// 解 XML 实体。`&amp;` 放最后，避免 `&amp;lt;` 被一次解成 `<`。
    private static func unescape(_ xml: String) -> String {
        var s = xml
        for (entity, plain) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
                                ("&#39;", "'"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: entity, with: plain)
        }
        return s
    }

    /// 红点是否该亮：只有比「已读版本」更新的版本才提示。
    /// 已读为空时以本地版本为基准（此时任何检测到的新版都算未读）。
    /// 纯函数、无副作用，便于 test.sh 直接验证。
    static func shouldShowDot(available: String?, acknowledged: String?, local: String) -> Bool {
        guard let available else { return false }
        return HUDVersion.isNewer(available, than: acknowledged ?? local)
    }

    private static func firstMatch(in text: String, pattern: String,
                                   options: NSRegularExpression.Options = []) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// 防重入：手动点「检查更新」与定时轮询可能同时触发
    private var inFlight = false

    func fetchLatest(completion: @escaping (Release?) -> Void) {
        guard !inFlight else { return }
        inFlight = true

        var req = URLRequest(url: Self.feedURL)
        req.timeoutInterval = 10
        req.setValue("ComateHUD/\(Self.localVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            let release = data
                .flatMap { String(data: $0, encoding: .utf8) }
                .flatMap(Self.parseLatest(feed:))
            // inFlight 与回调都回主线程，避免跨线程读写该标志
            DispatchQueue.main.async {
                self?.inFlight = false
                completion(release)
            }
        }.resume()
    }

    /// 「已是最新版本 v1.4.5 · 2 分钟前」里的相对时间。
    /// 不引 RelativeDateTimeFormatter：它按系统语言输出，测试无法钉住；这里分段拼字。
    /// `nil` 或时间戳在未来（改过系统时间）返回空串，调用方回退到不带时间的写法。
    static func relativeDescription(since date: Date?, now: Date = Date()) -> String {
        guard let date = date else { return "" }
        let seconds = Int(now.timeIntervalSince(date))
        guard seconds >= 0 else { return "" }
        switch seconds {
        case ..<60: return "刚刚"
        case ..<3600: return "\(seconds / 60) 分钟前"
        case ..<86400: return "\(seconds / 3600) 小时前"
        default: return "\(seconds / 86400) 天前"
        }
    }
}
