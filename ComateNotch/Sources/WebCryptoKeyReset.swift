import Foundation
import Security

/// 启动时按「代码身份」重置 WebKit 的 WebCrypto 主密钥钥匙串条目。
///
/// **为什么必须这么做**（2026-09-28 实测，securityd 日志为准）：
/// 登录页在 WKWebView 里用到 WebCrypto 时，WebKit 会自己创建钥匙串条目
/// `com.apple.WebKit.WebCrypto.master+com.wpscomate.hud` —— 换成
/// `WKWebsiteDataStore.nonPersistent()`（内存态 store）**也照样建**。
/// 该条目的 **partition 列表记录的是创建它的那次构建的身份**。我们的本地自签名证书没有
/// Team ID（`codesign -dvv` 显示 `TeamIdentifier=not set`，证书 subject 里也没有 OU），
/// partition 只能退化成 `cdhash:H"…"` —— 每次重建 / 每次发版 cdhash 都变，于是 securityd 判定
/// `ACL partition mismatch`，弹「ComateHUD 想要使用你储存在钥匙串中的…」，且点「始终允许」也记不住。
///
/// 注意：**只换稳定签名身份解决不了这个问题**。稳定身份稳住的是 ACL 的**应用列表**
/// （指定要求 `identifier "com.wpscomate.hud" and certificate root = H"…"` 跨构建恒定），
/// 而 partition 仍按 cdhash 走 —— 这是两套独立的校验，之前只修掉了前者。
///
/// **修法**：本 App 的身份一变，就把这条条目删掉，让 WebKit 用**当前身份**重建；
/// partition 天然匹配，框不再弹。条目只用于加密「浏览器持久存储里的 WebCrypto 密钥」
/// （`icmt` = "Used to encrypt WebCrypto keys in persistent storage, such as IndexedDB"），
/// 而 HUD 的登录页跑在内存态 store 上、不持久化任何东西 —— 轮换它没有任何代价，
/// 条目内容也与账号 / 密码 / `wps_sid` 无关。
///
/// 只在身份真的变了才删：否则每次启动都换主密钥，既没必要也让日志变噪。
enum WebCryptoKeyReset {
    /// WebKit 的命名约定：条目 account = `com.apple.WebKit.WebCrypto.master+<bundle id>`
    static let accountPrefix = "com.apple.WebKit.WebCrypto.master+"

    /// 上次清理时的代码身份（cdhash 十六进制）。与当前身份不同 = 换了构建，需要清理
    static let identityKey = "hud.webcryptoKeyReset.identity"

    /// 该不该清理：当前身份取得到、且与上次记录的不同（首次运行也算）。
    /// 身份取不到时不动钥匙串 —— 宁可漏清（下次登录可能弹一次）也不要瞎删。
    static func shouldReset(recorded: String?, current: String?) -> Bool {
        guard let current = current, !current.isEmpty else { return false }
        return recorded != current
    }

    /// 启动早期调用（任何 WKWebView 被创建之前）。返回是否真的删掉了条目。
    @discardableResult
    static func resetIfIdentityChanged(defaults: UserDefaults = .standard) -> Bool {
        let current = currentCodeIdentity()
        guard shouldReset(recorded: defaults.string(forKey: identityKey), current: current) else {
            return false
        }
        let outcome = deleteWebCryptoItems()
        let shown = current.map { String($0.prefix(12)) } ?? "未知"
        if outcome.ok {
            // 只有删干净（或本来就没有）才记身份：删除失败时留下旧记录，下次启动重试，
            // 否则一次失败就永久放弃了，用户会一直看到弹框
            defaults.set(current, forKey: identityKey)
            NSLog("[ComateHUD] 代码身份已变化（cdhash %@…），已清理 WebKit WebCrypto 主密钥条目 %d 条",
                  shown, outcome.removed)
        } else {
            NSLog("[ComateHUD] 代码身份已变化（cdhash %@…），WebCrypto 主密钥条目只清理了 %d 条，下次启动重试",
                  shown, outcome.removed)
        }
        return outcome.removed > 0
    }

    /// 当前可执行文件的代码身份 = cdhash（securityd 判 partition 用的就是它）。
    /// 取不到（极少见）返回 nil。
    static func currentCodeIdentity() -> String? {
        var selfCode: SecCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode = selfCode else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &staticCode) == errSecSuccess,
              let staticCode = staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any],
              let unique = dict[kSecCodeInfoUnique as String] as? Data else { return nil }
        return unique.map { String(format: "%02x", $0) }.joined()
    }

    /// 删除本 bundle 对应的 WebCrypto 主密钥条目。
    ///
    /// 查条目时**不取数据**（`kSecReturnRef`）—— 读取密钥内容才会走 ACL 授权，取引用不会，
    /// 所以我们的清理本身永远不会弹框。删除也不需要钥匙串密码（实测：
    /// `SecKeychainItemDelete` 对一条自己不在 ACL 里的条目返回 errSecSuccess，无弹框）。
    ///
    /// - Returns: (删掉的条数, 是否全部成功)。`errSecItemNotFound` 视为成功（本来就没有）。
    static func deleteWebCryptoItems(bundleID: String? = Bundle.main.bundleIdentifier) -> (removed: Int, ok: Bool) {
        guard let bundleID = bundleID, !bundleID.isEmpty else { return (0, false) }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: accountPrefix + bundleID,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnRef: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return (0, true) }
        guard status == errSecSuccess, let items = result as? [AnyObject], !items.isEmpty else {
            NSLog("[ComateHUD] 查询 WebCrypto 主密钥条目失败（OSStatus %d）", status)
            return (0, false)
        }

        var removed = 0
        var ok = true
        // 万一某条目的 ACL 要求交互（理论上不该发生），也别把启动流程卡在对话框上
        _ = SecKeychainSetUserInteractionAllowed(false)
        defer { _ = SecKeychainSetUserInteractionAllowed(true) }
        for case let item as SecKeychainItem in items {
            let deleted = SecKeychainItemDelete(item)
            if deleted == errSecSuccess {
                removed += 1
            } else {
                ok = false
                NSLog("[ComateHUD] 删除 WebCrypto 主密钥条目失败（OSStatus %d）", deleted)
            }
        }
        return (removed, ok)
    }
}
