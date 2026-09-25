import Foundation

// 纯逻辑测试：不启动 UI，直接断言那些可以脱离界面验证的规则。
// 覆盖三类最容易在重构中悄悄改坏、又最容易被界面「看起来正常」掩盖的逻辑：
// 版本比较、面板高度公式、状态灯判定。
//
// 用顶层代码而不是 XCTest：本仓库是手写 build.sh、无 SPM 依赖，
// 引入 XCTest 需要额外 target 与测试宿主，代价远大于收益。

var checks = 0
var failures = 0

func check(_ condition: Bool, _ name: String) {
    checks += 1
    if condition {
        print("  ✓ \(name)")
    } else {
        print("  ✗ \(name)")
        failures += 1
    }
}

func eq<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    checks += 1
    if actual == expected {
        print("  ✓ \(name)")
    } else {
        print("  ✗ \(name)  期望 \(expected)，实际 \(actual)")
        failures += 1
    }
}

func section(_ title: String) { print("\n\(title)") }

// MARK: - 版本比较

section("HUDVersion 版本比较")
eq(HUDVersion.segments("v1.4.10"), [1, 4, 10], "v1.4.10 → [1,4,10]")
eq(HUDVersion.segments("1.4.1-beta.1"), [1, 4, 1], "预发布后缀不参与比较")
check(HUDVersion.isNewer("v1.4.2", than: "1.4.1"), "1.4.2 > 1.4.1")
check(!HUDVersion.isNewer("1.4.1", than: "1.4.1"), "同版本不算更新")
check(HUDVersion.isNewer("1.10.0", than: "1.9.9"), "1.10 > 1.9（语义比较而非字符串比较）")
check(!HUDVersion.isNewer("1.4", than: "1.4.0"), "1.4 == 1.4.0（段数补齐）")
check(HUDVersion.isNewer("1.4.1", than: "1.4"), "1.4.1 > 1.4")
check(!HUDVersion.isNewer("v1.4.1-beta.1", than: "1.4.1"), "同号预发布不算更新")
check(HUDVersion.isNewer("2.0.0", than: "1.99.99"), "主版本优先于次版本")
check(!HUDVersion.isNewer("", than: "1.0"), "空版本号不误判为更新")
check(!HUDVersion.isNewer("v1.4.2-11", than: "1.4.2"), "静默发版 tag（同营销版本 + build 后缀）不算更新 → 不亮红点")
check(HUDVersion.isNewer("v1.4.2-11", than: "1.4.1"), "静默发版对更早版本的用户仍然提示更新")
check(HUDVersion.isNewer("v1.4.3", than: "1.4.2"), "升营销版本则提示更新")

// MARK: - releases.atom 解析

section("UpdateChecker 解析 releases.atom")
let feedSample = """
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Release notes from comate-hud</title>
  <entry>
    <id>tag:github.com,2008:Repository/1/v1.4.2</id>
    <link rel="alternate" type="text/html" href="https://github.com/likelu9/comate-hud/releases/tag/v1.4.2"/>
    <title>Comate HUD v1.4.2</title>
  </entry>
  <entry>
    <id>tag:github.com,2008:Repository/1/v1.4.1</id>
    <link rel="alternate" type="text/html" href="https://github.com/likelu9/comate-hud/releases/tag/v1.4.1"/>
    <title>Comate HUD v1.4.1</title>
  </entry>
</feed>
"""
let parsed = UpdateChecker.parseLatest(feed: feedSample)
eq(parsed?.version, "1.4.2", "取第一条 entry（feed 倒序 = 最新）")
eq(parsed?.url?.absoluteString, "https://github.com/likelu9/comate-hud/releases/tag/v1.4.2",
   "带出发布页链接")
check(HUDVersion.isNewer(parsed?.version ?? "", than: "1.4.1"), "解析出的版本判定为有更新")
check(UpdateChecker.parseLatest(feed: "") == nil, "空 feed 返回 nil 而不是崩")
check(UpdateChecker.parseLatest(feed: "<feed><title>无 entry</title></feed>") == nil,
      "没有 entry 时返回 nil")
eq(UpdateChecker.parseLatest(
    feed: "<entry><link rel=\"alternate\" href=\"https://github.com/x/y/releases/tag/v2.0.3\"/><title>Release</title></entry>"
)?.version, "2.0.3", "标题里没有版本号时退回 tag")

// MARK: - 面板高度公式

section("NotchLayout 高度公式")
let layout = NotchLayout(notchHeight: 32)
let rowUnit: CGFloat = 40
let footer: CGFloat = 20

eq(layout.topInset, 40, "topInset = 刘海高/2 + 24")
let oneRow = layout.contentHeight(forRows: 1, rowUnit: rowUnit, footerHeight: footer)
let threeRows = layout.contentHeight(forRows: 3, rowUnit: rowUnit, footerHeight: footer)
eq(threeRows - oneRow, 2 * rowUnit, "每多一条多一个 rowUnit")
eq(layout.contentHeight(forRows: 0, rowUnit: rowUnit, footerHeight: footer), oneRow,
   "0 条按 1 条算（不留空面板）")
eq(layout.contentHeight(forRows: 3, rowUnit: 0, footerHeight: footer),
   NotchLayout.fallbackExpandedHeight, "未测量出行高时用兜底高度")
eq(layout.contentHeight(forRows: 3, rowUnit: rowUnit, footerHeight: 0),
   NotchLayout.fallbackExpandedHeight, "未测量出页脚高度时用兜底高度")

let maxHeight = layout.contentHeight(forRows: NotchLayout.maxRowCount,
                                     rowUnit: rowUnit, footerHeight: footer)
eq(layout.clampedHeight(10, rowUnit: rowUnit, footerHeight: footer), oneRow,
   "自定义高度过低被夹到下限")
eq(layout.clampedHeight(99_999, rowUnit: rowUnit, footerHeight: footer), maxHeight,
   "自定义高度过高被夹到上限")
eq(layout.clampedHeight(threeRows, rowUnit: rowUnit, footerHeight: footer), threeRows,
   "区间内原样返回")

check(NotchLayout.resizeHitHeight < NotchLayout.bottomPadding,
      "拖拽手柄命中区比底部留白矮（否则会盖住页脚按钮）")
check(NotchLayout.maxRowCount >= 3, "最大高度至少覆盖 3 条")

eq(layout.listViewportHeight(targetExpandedHeight: maxHeight, rowsHeight: 10_000, footerHeight: footer),
   maxHeight - layout.topInset - NotchLayout.blockSpacing - footer - NotchLayout.bottomPadding,
   "内容超出时列表视口被裁剪")
eq(layout.listViewportHeight(targetExpandedHeight: maxHeight, rowsHeight: 10, footerHeight: footer),
   10, "内容装得下时贴合内容高度")
eq(layout.listViewportHeight(targetExpandedHeight: maxHeight, rowsHeight: 10, footerHeight: 0),
   10, "页脚未测量时不裁剪")

// MARK: - 状态灯判定

func makeTask(status: String = "idle",
              source: String = "local",
              lastMessageRole: String = "assistant",
              waitingSince: Date? = nil,
              faultSince: Date? = nil,
              activityAt: Date = Date(),
              doneSeenAt: Date? = nil,
              hasUnfinishedToolCall: Bool = false,
              lastJournalEventRole: String? = nil) -> ComateTask {
    ComateTask(id: "t", title: "任务", status: status, lastMessageRole: lastMessageRole,
               messageCount: 1, updatedAt: Date(), sessionFile: nil, source: source,
               waitingSince: waitingSince, waitingQuestion: nil,
               faultSince: faultSince, faultReason: "模型不可用",
               consumedTokens: nil, hasUnfinishedToolCall: hasUnfinishedToolCall,
               activityAt: activityAt, lastJournalEventRole: lastJournalEventRole,
               doneSeenAt: doneSeenAt)
}

section("ComateTask 状态灯")
eq(makeTask(status: "running", source: "cloud").light, .yellow, "云端 running → 黄")
eq(makeTask(status: "done", source: "cloud").light, .green, "云端 done → 绿")
eq(makeTask(status: "idle", source: "cloud").light, .gray, "云端 idle → 灰")

eq(makeTask(lastMessageRole: "user").light, .yellow, "本地：末条是用户消息 + 心跳新鲜 → 黄")
eq(makeTask(lastJournalEventRole: "toolResult").light, .yellow,
   "本地：末条是工具结果（模型还没落库）→ 黄")
eq(makeTask(hasUnfinishedToolCall: true).light, .yellow, "本地：还有未收尾的工具调用 → 黄")
eq(makeTask(lastMessageRole: "user", activityAt: Date().addingTimeInterval(-3600)).light, .gray,
   "心跳停住的轮次不再算「工作中」")
eq(makeTask(status: "done").light, .green, "本地：status=done → 绿")
eq(makeTask(doneSeenAt: Date().addingTimeInterval(-60)).light, .green,
   "15 分钟内看到过 done → 保持绿")
eq(makeTask(doneSeenAt: Date().addingTimeInterval(-3600)).light, .gray, "超过绿灯窗口 → 回落到灰")
eq(makeTask(waitingSince: Date()).light, .red, "正在等你确认 → 红")
eq(makeTask(waitingSince: Date().addingTimeInterval(-200_000)).light, .gray, "两天前的等待不再红")
eq(makeTask(faultSince: Date()).light, .red, "轮次异常 → 红")
eq(makeTask(waitingSince: Date(), faultSince: Date()).redKind, .waitingConfirmation,
   "同时等待与异常时优先报「等待确认」")
check(makeTask(lastMessageRole: "user").isRunning, "isRunning 与黄灯一致")
check(!makeTask().isRunning, "空闲任务 isRunning 为 false")

section("ComateTask 文案")
eq(makeTask(faultSince: Date()).statusLabel, "模型不可用", "红灯文案优先用异常原因")
eq(makeTask(waitingSince: Date()).statusLabel, "等待确认", "等待确认文案")
eq(makeTask(lastMessageRole: "user").statusLabel, "工作中", "黄灯文案")
eq(makeTask(status: "done").statusLabel, "已完成", "绿灯文案")
eq(makeTask().statusLabel, "空闲", "灰灯文案")
eq(makeTask(source: "cloud").sourceIcon, "icloud.fill", "云端任务用云图标")
eq(makeTask().sourceIcon, "folder.fill", "本地任务用文件夹图标")
eq(makeTask().metaLabel, "—", "没有智点记录时给占位符而不是 0 点")

// MARK: - 更新红点的「已读」判定

section("UpdateChecker 红点是否该亮（已读版本）")
let localVersion = "1.2.0"
check(UpdateChecker.shouldShowDot(available: "1.4.2", acknowledged: nil, local: localVersion),
      "从未点开过 → 亮")
check(!UpdateChecker.shouldShowDot(available: "1.4.2", acknowledged: "1.4.2", local: localVersion),
      "点开过同一版本 → 灭")
check(UpdateChecker.shouldShowDot(available: "1.4.3", acknowledged: "1.4.2", local: localVersion),
      "出现更新的版本 → 重新亮")
check(!UpdateChecker.shouldShowDot(available: "1.4.2", acknowledged: "1.4.3", local: localVersion),
      "已读版本更高时不倒退提示")
check(!UpdateChecker.shouldShowDot(available: nil, acknowledged: nil, local: localVersion),
      "没检测到新版 → 不亮")
check(!UpdateChecker.shouldShowDot(available: "1.4.2", acknowledged: nil, local: "1.4.2"),
      "与本地同版本 → 不亮")
check(!UpdateChecker.shouldShowDot(available: "v1.4.2", acknowledged: "1.4.2", local: localVersion),
      "带 v 前缀与已读版本视为同一版本")
check(!UpdateChecker.shouldShowDot(available: "v1.4.2-11", acknowledged: nil, local: "1.4.2"),
      "静默发版（只升 build）对同营销版本用户不亮红点")

// MARK: - 汇总

print("\n———————————————")
if failures == 0 {
    print("✅ \(checks) 项断言全部通过")
    exit(0)
} else {
    print("❌ \(failures)/\(checks) 项断言失败")
    exit(1)
}
