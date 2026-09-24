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
        return Release(version: version, url: href.flatMap(URL.init(string:)))
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
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
}
