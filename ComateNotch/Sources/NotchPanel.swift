import AppKit

/// 贴合 MacBook 刘海的悬浮 HUD 窗口。
/// - 无边框、置顶、不抢焦点、覆盖屏幕顶部
/// - 有刘海时居中贴合刘海；无刘海时居中悬浮于顶部
final class NotchPanel: NSPanel {

    init() {
        let frame = NotchPanel.targetFrame()
        let styleMask: NSWindow.StyleMask = [
            .borderless,
            .fullSizeContentView,
            .nonactivatingPanel
        ]
        super.init(contentRect: frame,
                   styleMask: styleMask,
                   backing: .buffered,
                   defer: false)
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.ignoresMouseEvents = false
        self.titleVisibility = .hidden
        self.title = ""
        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - 定位

    static func targetFrame() -> NSRect {
        guard let screen = NSScreen.screens.first else {
            return NSRect(x: 0, y: 0, width: 240, height: 34)
        }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // 是否有刘海：visibleFrame.maxY < screenFrame.maxY 说明顶部有传感器区
        let hasNotch: Bool = {
            if #available(macOS 12.0, *) {
                return screen.safeAreaInsets.top > 0
            }
            return false
        }()

        let notchWidth: CGFloat = hasNotch ? 200 : 240
        let notchHeight: CGFloat = hasNotch ? 34 : 34
        let cx = screenFrame.midX
        // 紧贴屏幕顶部（刘海机型下与刘海齐平）
        let topY = screenFrame.maxY - notchHeight
        let x = cx - notchWidth / 2

        _ = visibleFrame
        return NSRect(x: x, y: topY, width: notchWidth, height: notchHeight)
    }
}
