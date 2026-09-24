import Foundation

/// Comate 用户身份（用户名 + uid）
///
/// 来源：官网 BaaS 的 auth 接口（与 ComateHUD/index.html 同一个项目），用 keychain 里的 wps_sid 鉴权：
///   POST {base}/api/manage/v1/db/auth   {"action":"get_user"}
///   → {"code":0,"data":{"user_id":"1388246874","nickname":"李柯陆",...}}
///
/// 为什么不用本地来源：Comate 客户端本地的 ksoaccount/default.ini 只有明文 userId，
/// 用户名是 @ByteArray 加密串；Comate 的本地库/接口都没有用户信息端点。
/// 所以以 BaaS auth 接口为准 —— 取不到就不上报（宁缺勿假，避免把别人的名字记到某个 uid 上）。
final class UserIdentity {
    static let shared = UserIdentity()

    struct Identity {
        let uid: String
        let nickname: String
    }

    private static let baseURL = "https://o.wpsgo.com/app/app-base"
    private static let projectId = "3171466180955374"
    private static let timeout: TimeInterval = 8

    private let lock = NSLock()
    private var cached: Identity?
    private var cachedSid: String?

    /// 取身份（阻塞，必须在后台队列调用）。sid 变化会重新取（换账号场景）。
    func current(sid: String) -> Identity? {
        lock.lock()
        if let c = cached, cachedSid == sid { lock.unlock(); return c }
        lock.unlock()
        guard let identity = fetch(sid: sid) else { return nil }
        lock.lock()
        cached = identity
        cachedSid = sid
        lock.unlock()
        return identity
    }

    private func fetch(sid: String) -> Identity? {
        guard let url = URL(string: "\(Self.baseURL)/api/manage/v1/db/auth") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = Self.timeout
        req.setValue("wps_sid=\(sid)", forHTTPHeaderField: "Cookie")
        req.setValue(Self.projectId, forHTTPHeaderField: "X-Project-Id")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "get_user"])

        var result: Identity?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { sem.signal() }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let obj = json["data"] as? [String: Any] else { return }
            // uid 可能是字符串或数字，两种都收
            let uid: String?
            if let s = obj["user_id"] as? String { uid = s }
            else if let n = obj["user_id"] as? NSNumber { uid = n.stringValue }
            else { uid = nil }
            guard let id = uid, !id.isEmpty else { return }
            result = Identity(uid: id, nickname: (obj["nickname"] as? String) ?? "")
        }.resume()
        _ = sem.wait(timeout: .now() + Self.timeout + 1)
        if result == nil {
            NSLog("[ComateHUD] 取用户身份失败（BaaS auth 接口）")
        }
        return result
    }
}
