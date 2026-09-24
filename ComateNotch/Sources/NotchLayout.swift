import CoreGraphics

/// 刘海面板的布局计算：从 NotchRootView 抽出的纯函数与常量。
///
/// 抽出来的两个理由：
/// 1. 高度公式与 padding / spacing 必须同源 —— 分散在视图里时，改了 padding 忘了改公式
///    就会出现「内容被裁掉一截」这类看不出原因的隐形漂移；
/// 2. 纯函数可以脱离 SwiftUI 直接验证（见 test.sh 的布局用例）。
///
/// 这些常量必须与 expandedContent 的 padding / spacing 保持一致。
struct NotchLayout {
    /// 刘海高度，决定顶部内缩量
    let notchHeight: CGFloat

    static let horizontalPadding: CGFloat = 12
    static let listSpacing: CGFloat = 3
    static let blockSpacing: CGFloat = 6
    /// 面板底部留白：页脚下方必须留出比拖拽手柄命中区更高的空白，
    /// 否则手柄会盖住页脚按钮的命中区（12 > resizeHitHeight）
    static let bottomPadding: CGFloat = 12
    /// 拖拽手柄的可视条高度（含条下方留白）
    static let resizeHandleHeight: CGFloat = 14
    /// 拖拽手柄的命中区高度：只取面板最底部这一条，避开页脚
    static let resizeHitHeight: CGFloat = 10
    /// 无任务时列表占位文案的高度
    static let emptyPlaceholderHeight: CGFloat = 24
    /// 首次测量完成前的兜底高度
    static let fallbackExpandedHeight: CGFloat = 280
    /// 最大高度对应的记录条数（菜单可选条数的最大值）
    static var maxRowCount: Int { ComateStore.recentTaskLimitOptions.max() ?? 10 }

    var topInset: CGFloat { notchHeight / 2 + 24 }

    /// 单行占高（行高 + 行间距）：由实测行高反推。
    /// 它只取决于行本身，与当前展示多少条无关，所以切换条数时依然有效。
    static func rowUnit(rowsHeight: CGFloat, measuredRowCount: Int) -> CGFloat {
        guard measuredRowCount > 0, rowsHeight > 0 else { return 0 }
        return (rowsHeight + listSpacing) / CGFloat(measuredRowCount)
    }

    /// 指定条数时面板应有的高度（即内容自适应高度）。
    /// 还没测量出行高 / 页脚高度时返回兜底高度。
    func contentHeight(forRows rows: Int, rowUnit: CGFloat, footerHeight: CGFloat) -> CGFloat {
        guard rowUnit > 0, footerHeight > 0 else { return Self.fallbackExpandedHeight }
        return topInset
            + rowUnit * CGFloat(max(rows, 1))
            - Self.listSpacing
            + Self.blockSpacing
            + footerHeight
            + Self.bottomPadding
    }

    /// 展开态实际高度：把自定义高度夹在 [1 条, 10 条] 之间
    func clampedHeight(_ custom: CGFloat, rowUnit: CGFloat, footerHeight: CGFloat) -> CGFloat {
        let minH = contentHeight(forRows: 1, rowUnit: rowUnit, footerHeight: footerHeight)
        let maxH = contentHeight(forRows: Self.maxRowCount, rowUnit: rowUnit, footerHeight: footerHeight)
        return min(max(custom, minH), maxH)
    }

    /// 列表可视高度：装得下就贴合内容，装不下则裁剪并可滚动
    func listViewportHeight(targetExpandedHeight: CGFloat,
                            rowsHeight: CGFloat,
                            footerHeight: CGFloat) -> CGFloat {
        guard footerHeight > 0 else { return rowsHeight }
        let avail = targetExpandedHeight - topInset - Self.blockSpacing - footerHeight - Self.bottomPadding
        return max(min(rowsHeight, avail), 0)
    }
}
