import Foundation

/// 每日活跃上报
///
/// 口径（与官网统计面板一致）：
/// - 当天应用启动过即算活跃（HUD 常驻，不要求有交互）
/// - 另外埋点：面板 hover 展开次数、面板内点击次数 —— 只在本机累计，随日报集中上报，不实时打接口
///
/// 上报策略：
/// - 跨天后的第一个节拍上报「昨天」的桶；应用退出时兜底上报「今天」的桶（正常情况一天 1 次请求）
/// - 桶持久化在 UserDefaults，每次计数变更即落盘 —— 进程被杀/断电也不丢，下次启动补报
/// - 服务端按 uid + active_day 预查：没有就插入，已有则按「当天累计值」覆盖更新。
///   发的是累计总量而不是增量，所以重试、重复上报、多设备各报一次都不会把数字越加越大。
///
/// 身份：
/// - BaaS 全表要求登录（实测无 Cookie 直接 401），所以读不到 wps_sid 就没有上报通道，只能跳过
/// - 有凭据但 BaaS auth 取不到用户时，退化为设备维度 uid（anon-xxx），不编造昵称
/// - 401/403 视为「凭据无权限」，退避一段时间再试，避免每 5 分钟撞一次
final class ActivityReporter {
    static let shared = ActivityReporter()

    // MARK: - 上报目标
    /// 官网 BaaS 项目（ComateHUD/index.html 所在项目，不是 Comate 根项目 3599569812562023）
    private static let projectId = "3171466180955374"
    private static let baseURL = "https://o.wpsgo.com/app/app-base"
    private static let table = "app_activity"
    /// 日期口径：北京时间（与官网统计面板一致，不随用户系统时区漂移）
    private static let timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone.current

    // MARK: - 事件
    enum Event {
        case launch
        case hover
        case click
    }

    /// 单次上报结果。401/403 是「这个凭据没权限」，重试不会变好，要退避
    private enum SendResult {
        case ok
        case authFailed
        case failed
    }

    /// 一天的活跃事实累计
    struct Bucket: Codable {
        var day: String            // yyyyMMdd（北京时区）
        var firstActiveAt: String  // ISO8601，当天首次活跃时刻
        var launchCount: Int
        var hoverCount: Int
        var clickCount: Int
        var dirty: Bool            // 有未上报的变更
    }

    /// 凭据提供者：由 ComateStore 注入（复用它的 keychain 缓存与串行锁，避免重复 fork security）
    var credentialProvider: (() -> String?)?

    private let lock = NSLock()
    private var bucket: Bucket?
    private var pending: [Bucket] = []
    private var lastAttempt = Date.distantPast
    private var flushing = false
    /// 鉴权失败后的静默期截止时刻（只存内存：重启后允许再试一次）
    private var authFailedUntil = Date.distantPast

    private static let bucketKey = "notch.activity.bucket"
    private static let pendingKey = "notch.activity.pending"
    private static let deviceIdKey = "notch.activity.deviceId"
    /// 失败后的重试间隔：一天只有一两次请求，失败就尽快补，不必等下一个节拍
    private static let retryInterval: TimeInterval = 300
    /// 鉴权失败（401/403）后的静默期：重试同一个凭据不会变好，等 Comate 刷新登录态或换账号
    private static let authBackoff: TimeInterval = 6 * 3600
    /// 单次上报超时
    private static let requestTimeout: TimeInterval = 15

    private init() {
        load()
    }

    // MARK: - 记录

    /// 记录一次活跃事件（主线程调用，纯内存 + UserDefaults 写入）
    func record(_ event: Event) {
        lock.lock()
        var b = currentBucketLocked()
        switch event {
        case .launch: b.launchCount += 1
        case .hover:  b.hoverCount += 1
        case .click:  b.clickCount += 1
        }
        b.dirty = true
        bucket = b
        let snapshot = (bucket: bucket, pending: pending)
        lock.unlock()
        persist(snapshot.bucket, snapshot.pending)
    }

    /// 取当天桶（必要时滚动；调用方持锁）
    private func currentBucketLocked() -> Bucket {
        let today = Self.dayKey(Date())
        if let b = bucket, b.day == today { return b }
        // 跨天：旧桶还有未上报的变更就转入待补报队列，否则丢弃（已报过的桶无需重复发）
        if let old = bucket, old.dirty { pending.append(old) }
        return Bucket(day: today,
                      firstActiveAt: Self.iso8601(Date()),
                      launchCount: 0, hoverCount: 0, clickCount: 0, dirty: false)
    }

    // MARK: - 上报

    /// 节拍调用：跨天或有失败待补报时才真正发请求（正常一天只在这里发一次）
    func tick() {
        lock.lock()
        let today = Self.dayKey(Date())
        let rolled = (bucket?.day != today && bucket?.dirty == true)
        let hasPending = !pending.isEmpty
        let retryDue = Date().timeIntervalSince(lastAttempt) >= Self.retryInterval
        let busy = flushing
        let authBlocked = Date() < authFailedUntil
        lock.unlock()
        guard !busy else { return }
        guard !authBlocked else { return }
        guard rolled || hasPending else { return }
        guard retryDue else { return }
        flush()
    }

    /// 上报所有待发桶（可安全重复调用：发的是累计值）
    func flush() {
        lock.lock()
        if flushing { lock.unlock(); return }
        // 跨天先滚动，让昨天的桶进入待发队列
        let today = Self.dayKey(Date())
        if let b = bucket, b.day != today {
            if b.dirty { pending.append(b) }
            bucket = nil
        }
        var jobs = Self.mergeByDay(pending)
        if let b = bucket, b.dirty { jobs = Self.mergeByDay(jobs + [b]) }
        flushing = true
        lastAttempt = Date()
        lock.unlock()

        guard !jobs.isEmpty else {
            lock.lock(); flushing = false; lock.unlock()
            return
        }
        // 凭据读取会 fork security、身份接口要联网：整段放后台队列，主线程调用 flush 时不会卡面板
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            defer { self.lock.lock(); self.flushing = false; self.lock.unlock() }
            guard let sid = self.credentialProvider?() else {
                // BaaS 全表要求登录（实测无 Cookie 直接 401），没有凭据就没有任何上报通道
                NSLog("[ComateHUD] 活跃上报跳过：无凭据（未登录 Comate 桌面端）")
                return
            }
            let deviceId = Self.deviceId()
            // 取不到真实身份也要落行：uid 退化为设备维度（anon-<设备指纹前缀>），昵称留空。
            // 之前这里直接 return，导致「有凭据但 BaaS auth 取不到用户」的装机一条记录都不落。
            let identity: UserIdentity.Identity
            if let real = UserIdentity.shared.current(sid: sid) {
                identity = real
            } else {
                identity = UserIdentity.anonymous(deviceId: deviceId)
                NSLog("[ComateHUD] 取不到用户身份，按设备维度上报: %@", identity.uid)
            }
            let version = Self.appVersion()
            let osVersion = Self.osVersion()
            let group = DispatchGroup()
            for job in jobs {
                group.enter()
                self.send(job, identity: identity, sid: sid, deviceId: deviceId,
                          version: version, osVersion: osVersion) { result in
                    switch result {
                    case .ok:         self.markReported(day: job.day)
                    case .authFailed: self.markAuthFailed()
                    case .failed:     break
                    }
                    group.leave()
                }
            }
            // 在后台队列上等并发请求收尾（flushSync 靠 flushing 标志判断结束）
            group.wait()
        }
    }

    /// 退出时兜底上报：阻塞至多 timeout 秒（拿不到就留给下次启动补报，数据不会丢）
    func flushSync(timeout: TimeInterval = 3) {
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            self.flush()
            // flush 内部是并发请求，这里等到 flushing 落下
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                self.lock.lock(); let busy = self.flushing; self.lock.unlock()
                if !busy { break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout)
    }

    /// 标记某天已上报：从待补报队列移除；当天桶清 dirty
    private func markReported(day: String) {
        lock.lock()
        pending.removeAll { $0.day == day }
        if var b = bucket, b.day == day {
            b.dirty = false
            bucket = b
        }
        let snapshot = (bucket: bucket, pending: pending)
        lock.unlock()
        persist(snapshot.bucket, snapshot.pending)
        NSLog("[ComateHUD] 活跃上报成功: %@", day)
    }

    /// 鉴权失败：静默一段时间再试，避免每 5 分钟撞一次 401
    private func markAuthFailed() {
        lock.lock()
        authFailedUntil = Date().addingTimeInterval(Self.authBackoff)
        lock.unlock()
        NSLog("[ComateHUD] 活跃上报被拒（凭据无权限或已过期），静默 %d 小时后重试", Int(Self.authBackoff / 3600))
    }

    // MARK: - 网络

    /// HTTP 状态 → 上报结果。401/403 归为鉴权失败（重试同一个凭据不会变好）
    private static func result(from status: Int, ok: Bool = false) -> SendResult {
        if ok { return .ok }
        if status == 401 || status == 403 { return .authFailed }
        return .failed
    }

    private func send(_ job: Bucket, identity: UserIdentity.Identity, sid: String,
                      deviceId: String, version: String, osVersion: String,
                      completion: @escaping (SendResult) -> Void) {
        var row: [String: Any] = [
            "uid": identity.uid,
            "version": version,
            "active_day": job.day,
            "first_active_at": job.firstActiveAt,
            "launch_count": job.launchCount,
            "hover_count": job.hoverCount,
            "click_count": job.clickCount,
            "device_id": deviceId,
            "os_version": osVersion,
        ]
        // 兜底身份没有昵称：不写 user_name，避免把设备伪装成人（PATCH 时也不会抹掉已有的名字）
        if !identity.nickname.isEmpty { row["user_name"] = identity.nickname }
        // 预查：同一 uid + 同一天是否已有行（多设备/重装/当天二次启动都靠它收敛成一行）
        let filter = "filter.uid.eq=\(Self.encode(identity.uid))&filter.active_day.eq=\(Self.encode(job.day))"
        guard let queryURL = URL(string: "\(Self.baseURL)/api/manage/v1/db/rest/\(Self.table)?\(filter)") else {
            completion(.failed); return
        }
        request(queryURL, method: "GET", body: nil, sid: sid) { json, status in
            guard let json = json, (json["code"] as? Int) == 0 else {
                completion(Self.result(from: status)); return
            }
            let rows = ((json["data"] as? [String: Any])?["rows"] as? [[String: Any]]) ?? []
            if rows.isEmpty {
                // 无行 → 插入
                guard let url = URL(string: "\(Self.baseURL)/api/manage/v1/db/rest/\(Self.table)") else {
                    completion(.failed); return
                }
                self.request(url, method: "POST", body: [row], sid: sid) { res, status in
                    completion(Self.result(from: status, ok: (res?["code"] as? Int) == 0))
                }
            } else {
                // 已有行 → 覆盖为当前累计值（幂等：重发同样的值不会越加越大）
                let body: [String: Any] = [
                    "set": row,
                    "filter": [
                        "logic": "and",
                        "conditions": [
                            ["field": "uid", "operator": "eq", "value": identity.uid],
                            ["field": "active_day", "operator": "eq", "value": job.day],
                        ],
                    ],
                ]
                guard let url = URL(string: "\(Self.baseURL)/api/manage/v1/db/rest/\(Self.table)") else {
                    completion(.failed); return
                }
                self.request(url, method: "PATCH", body: body, sid: sid) { res, status in
                    completion(Self.result(from: status, ok: (res?["code"] as? Int) == 0))
                }
            }
        }
    }

    private func request(_ url: URL, method: String, body: Any?, sid: String,
                         completion: @escaping ([String: Any]?, Int) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = Self.requestTimeout
        req.setValue("wps_sid=\(sid)", forHTTPHeaderField: "Cookie")
        req.setValue(Self.projectId, forHTTPHeaderField: "X-Project-Id")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        URLSession.shared.dataTask(with: req) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let error = error {
                NSLog("[ComateHUD] 活跃上报请求失败: %@", error.localizedDescription)
                completion(nil, status); return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil, status); return
            }
            if (json["code"] as? Int) != 0 {
                NSLog("[ComateHUD] 活跃上报被拒: HTTP %d %@", status, String(describing: json["msg"] ?? json))
            }
            completion(json, status)
        }.resume()
    }

    // MARK: - 持久化

    private func persist(_ bucket: Bucket?, _ pending: [Bucket]) {
        let d = UserDefaults.standard
        d.set(bucket.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.bucketKey)
        d.set(try? JSONEncoder().encode(pending), forKey: Self.pendingKey)
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.bucketKey) {
            bucket = try? JSONDecoder().decode(Bucket.self, from: data)
        }
        if let data = d.data(forKey: Self.pendingKey) {
            pending = (try? JSONDecoder().decode([Bucket].self, from: data)) ?? []
        }
    }

    // MARK: - 工具

    /// 同一天的多份桶合并：计数取最大值（累计值是单调的，取 max 即最新），首次活跃取最早
    private static func mergeByDay(_ buckets: [Bucket]) -> [Bucket] {
        var byDay: [String: Bucket] = [:]
        for b in buckets {
            guard let cur = byDay[b.day] else { byDay[b.day] = b; continue }
            byDay[b.day] = Bucket(
                day: b.day,
                firstActiveAt: min(cur.firstActiveAt, b.firstActiveAt),
                launchCount: max(cur.launchCount, b.launchCount),
                hoverCount: max(cur.hoverCount, b.hoverCount),
                clickCount: max(cur.clickCount, b.clickCount),
                dirty: cur.dirty || b.dirty)
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    static func dayKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func iso8601(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
        return f.string(from: date)
    }

    /// 设备标识：首次生成后固定（不采集主机名/序列号等可识别信息）
    private static func deviceId() -> String {
        let d = UserDefaults.standard
        if let id = d.string(forKey: deviceIdKey), !id.isEmpty { return id }
        let id = UUID().uuidString
        d.set(id, forKey: deviceIdKey)
        return id
    }

    static func appVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
    }
}
