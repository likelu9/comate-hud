import AppKit

/// 开机自启：写用户级 LaunchAgent（~/Library/LaunchAgents/com.wpscomate.hud.plist）。
///
/// 没用 SMAppService 是因为它要求 macOS 13+，而本应用最低支持 12.0；
/// LaunchAgent 只写用户自己的目录，不需要任何额外权限。
/// 只在「首次启动默认开启」或用户在菜单里显式切换时写盘，关闭时删除该 plist。
enum LaunchAtLogin {
    static let label = "com.wpscomate.hud"
    /// 首次启动的默认开启是否已处理过（之后完全由用户控制，不再自动写）
    private static let initializedKey = "hud.launchAtLogin.initialized"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// 是否已启用。以 plist 是否存在为准 —— 菜单每次弹出重建，勾选态天然与磁盘一致
    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// 注册的路径是否稳定。从 DMG 挂载卷或 AppTranslocation 临时目录运行的可执行文件，
    /// 下次登录时该路径已不存在，注册了也不会自启（且会留下一个报错的 LaunchAgent）。
    static var isPathStable: Bool {
        guard let path = Bundle.main.executableURL?.path else { return false }
        return !path.contains("/AppTranslocation/") && !path.hasPrefix("/Volumes/")
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        enabled ? install() : remove()
    }

    /// 首次启动默认开启一次
    static func applyDefaultOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: initializedKey) else { return }
        defaults.set(true, forKey: initializedKey)
        guard isPathStable else { return }
        _ = install()
    }

    private static func install() -> Bool {
        guard let exe = Bundle.main.executableURL?.path else { return false }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        do {
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func remove() -> Bool {
        guard isEnabled else { return true }
        do {
            try FileManager.default.removeItem(at: plistURL)
            return true
        } catch {
            return false
        }
    }

    /// 路径不稳定时的提示：先把 App 拖进「应用程序」再开
    static func warnPathUnstable() {
        let alert = NSAlert()
        alert.messageText = "无法开启开机自启"
        alert.informativeText = """
            当前副本是从磁盘映像或临时位置运行的，重启后路径会失效，注册了也不会自启。
            请先把「Comate HUD.app」拖到「应用程序」文件夹，再从那里启动后开启。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
