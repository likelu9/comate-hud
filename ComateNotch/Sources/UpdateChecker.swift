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

/// 更新检测：读 GitHub Releases 的 latest tag，与本地 CFBundleShortVersionString 比对。
///
/// 走公开接口（无需 token，未鉴权限额 60 次/时，远高于 6 小时一次的轮询频率），
/// 任何失败都静默返回 nil —— 更新提醒是增值信息，不该干扰任务状态这类主功能。
final class UpdateChecker {
    struct Release {
        /// tag 名，如 "v1.4.2"
        let version: String
        /// 发布页（GitHub Release，公开可访问）
        let url: URL?
    }

    static let shared = UpdateChecker()
    static let apiURL = URL(string: "https://api.github.com/repos/likelu9/comate-hud/releases/latest")!

    /// 本地版本号，来源 Info.plist（版本号的唯一真源）
    static var localVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// 防重入：手动点「检查更新」与定时轮询可能同时触发
    private var inFlight = false

    func fetchLatest(completion: @escaping (Release?) -> Void) {
        guard !inFlight else { return }
        inFlight = true

        var req = URLRequest(url: Self.apiURL)
        req.timeoutInterval = 10
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ComateHUD/\(Self.localVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            var release: Release?
            if let data,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = obj["tag_name"] as? String {
                release = Release(version: tag,
                                  url: (obj["html_url"] as? String).flatMap(URL.init(string:)))
            }
            // inFlight 与回调都回主线程，避免跨线程读写该标志
            DispatchQueue.main.async {
                self?.inFlight = false
                completion(release)
            }
        }.resume()
    }
}
