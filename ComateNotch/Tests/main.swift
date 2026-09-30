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

// v2：写成「刘海高 + 固定净留白」，不再是 `notchHeight / 2 + 24` ——
// 后者在不同机型的刘海高度下净留白不一致（34pt 刘海只剩 7pt），而设计要的是与硬件无关的固定值
eq(layout.topInset, 32 + NotchLayout.notchClearance, "topInset = 刘海高 + 净留白")
eq(NotchLayout(notchHeight: 34).topInset - 34, NotchLayout.notchClearance,
   "换到 34pt 刘海机型净留白不变")
eq(NotchLayout(notchHeight: 24).topInset - 24, NotchLayout.notchClearance,
   "换到 24pt 刘海机型净留白不变")
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

// MARK: - 凭据校验与失效重试

section("AuthSession 的 sid 合法性校验")
check(AuthSession.isValidSid("V02Sabcdefghijklmnopqrstuvwxyz0123456789-_"), "正常 sid 通过")
check(!AuthSession.isValidSid(""), "空值不通过")
check(!AuthSession.isValidSid(String(repeating: "a", count: 513)), "超长不通过")
check(!AuthSession.isValidSid("abc def"), "含空格不通过")
check(!AuthSession.isValidSid("abc\r\nX-Evil: 1"), "含换行不通过（防请求头注入）")
check(!AuthSession.isValidSid("abc;def"), "含分号不通过")

section("凭据失效后是否值得重试")
check(!ComateStore.shouldRetryAfterAuthFailure(previous: "a", fresh: "a"), "还是同一把凭据 → 不重试")
check(!ComateStore.shouldRetryAfterAuthFailure(previous: "a", fresh: nil), "取不到凭据 → 不重试")
check(ComateStore.shouldRetryAfterAuthFailure(previous: "a", fresh: "b"), "换成新凭据 → 重试")

// MARK: - 上报退避阶梯

section("活跃上报的鉴权失败退避阶梯")
eq(ActivityReporter.authBackoffDelay(streak: 0), 30, "异常入参也取第一档")
eq(ActivityReporter.authBackoffDelay(streak: 1), 30, "第 1 次失败 30 秒后重试")
eq(ActivityReporter.authBackoffDelay(streak: 2), 60, "第 2 次 1 分钟")
eq(ActivityReporter.authBackoffDelay(streak: 3), 300, "第 3 次 5 分钟")
eq(ActivityReporter.authBackoffDelay(streak: 4), 900, "第 4 次 15 分钟")
eq(ActivityReporter.authBackoffDelay(streak: 5), 3600, "第 5 次 1 小时")
eq(ActivityReporter.authBackoffDelay(streak: 99), 3600, "继续失败停在 1 小时封顶")

// MARK: - 登录态与用量状态的收敛

section("取凭据失败不轻易判未登录")
check(ComateStore.shouldConcludeNoCredential(authState: .noCredential),
      "AuthSession 判无凭据 → 可以判未登录")
check(!ComateStore.shouldConcludeNoCredential(authState: .unknown),
      "登录态尚未判定 → 不判未登录（面板不能抢在判定前下结论）")
check(!ComateStore.shouldConcludeNoCredential(authState: .ok),
      "已判有凭据 → 不判未登录（冷启动首读可能空手而归）")
check(!ComateStore.shouldConcludeNoCredential(authState: .expired),
      "凭据失效 → 是重新登录提示，不是未登录")

section("凭据只存内存：从 cookie 里挑出 wps_sid")
let makeCookie: (String, String) -> HTTPCookie? = { name, value in
    HTTPCookie(properties: [.name: name, .value: value, .domain: "comate.wps.cn", .path: "/"])
}
check(AuthSession.sid(in: []) == nil, "没有 cookie → 无凭据")
check(AuthSession.sid(in: [makeCookie("other", "x")!]) == nil, "只有别的 cookie → 无凭据")
check(AuthSession.sid(in: [makeCookie("wps_sid", "V02Sabc")!]) == "V02Sabc", "取到 wps_sid")
check(AuthSession.sid(in: [makeCookie("wps_sid", "")!]) == nil, "空值的 wps_sid 不算凭据")
check(ComateStore.credentialReadRetryInterval < ComateStore.retryDelay(failures: 1, authFailed: false),
      "瞬时读失败不像真失败那样退避 60 秒")
check(ComateStore.usageRetryDelay(retryAfter: Date().addingTimeInterval(5), now: Date()) < 6,
      "重试延迟由退避时刻决定，不被频次上限夹到 30 秒")
check(ComateStore.usageRetryDelay(retryAfter: .distantPast, now: Date()) == 0.5,
      "退避时刻已过则只留半秒容差")

section("启动探测不覆盖真实请求的结论")
check(AuthSession.probeCanApply(currentState: .unknown),
      "还没结论 → 探测可以填")
check(!AuthSession.probeCanApply(currentState: .ok),
      "真实请求已判有凭据 → 探测不能把它改成无凭据")
check(!AuthSession.probeCanApply(currentState: .expired),
      "真实请求已判失效 → 探测不能把它改回有凭据")
check(!AuthSession.probeCanApply(currentState: .noCredential),
      "已有无凭据结论 → 不重复下发状态变化")

section("WebCrypto 主密钥条目重置（消登录弹框）")
check(WebCryptoKeyReset.shouldReset(recorded: nil, current: "abc"),
      "首次运行（没有记录）→ 清理一次")
check(WebCryptoKeyReset.shouldReset(recorded: "abc", current: "def"),
      "重建/发版后 cdhash 变了 → 必须清理（否则 partition 不匹配会弹框）")
check(!WebCryptoKeyReset.shouldReset(recorded: "abc", current: "abc"),
      "身份没变 → 不动钥匙串，不无谓轮换主密钥")
check(!WebCryptoKeyReset.shouldReset(recorded: "abc", current: nil),
      "身份取不到 → 宁可不清理，也不瞎删条目")
check(!WebCryptoKeyReset.shouldReset(recorded: nil, current: nil),
      "两边都空 → 不清理")
check(!WebCryptoKeyReset.shouldReset(recorded: "abc", current: ""),
      "空身份不算身份变化")
eq(WebCryptoKeyReset.accountPrefix, "com.apple.WebKit.WebCrypto.master+",
   "account 前缀与 WebKit 的命名约定一致（写错就等于没清）")

section("账号信息解析（菜单展示用）")
if let full = UsageAPI.parseAccount(["code": 0, "data": [
    "nickname": "李柯陆", "company_name": "金山办公软件有限公司", "user_id": 1388246874,
]]) {
    check(full.nickname == "李柯陆", "取到账号名")
    check(full.companyName == "金山办公软件有限公司", "取到企业名")
} else {
    check(false, "完整响应应能解析出账号")
}
if let onlyName = UsageAPI.parseAccount(["data": ["nickname": "李柯陆"]]) {
    check(onlyName.companyName.isEmpty, "接口没给企业名时留空，不编造")
} else {
    check(false, "只有账号名也应算解析成功")
}
check(UsageAPI.parseAccount(["data": ["nickname": "", "company_name": ""]]) == nil,
      "两样都没有 → 视为取不到，菜单回退「已登录」")
check(UsageAPI.parseAccount([:]) == nil, "空响应不报错")

section("刘海目标屏幕：生效屏解析")
let builtin = NotchScreenTarget.Option(id: 1, name: "内置显示器", isMain: true)
let dellA = NotchScreenTarget.Option(id: 2, name: "DELL U2720Q", isMain: false)
let dellB = NotchScreenTarget.Option(id: 3, name: "DELL U2720Q", isMain: false)
check(NotchScreenTarget.resolve(saved: nil, options: [builtin, dellA])?.id == 1,
      "没选过 → 跟随主屏（默认行为与改动前一致）")
check(NotchScreenTarget.resolve(saved: 2, options: [builtin, dellA])?.id == 2,
      "选过 → 停在选中的那块")
check(NotchScreenTarget.resolve(saved: 9, options: [builtin, dellA])?.id == 1,
      "选中的屏被拔掉 → 临时回退主屏")
check(NotchScreenTarget.resolve(saved: 2, options: [dellA, dellB])?.id == 2,
      "没有主屏标记时，选中的屏仍然优先")
check(NotchScreenTarget.resolve(saved: nil, options: [dellA, dellB])?.id == 2,
      "没有主屏标记 → 退回第一块，不返回 nil")
check(NotchScreenTarget.resolve(saved: 9, options: []) == nil,
      "一块屏都没有 → nil，由调用方兜底")

section("刘海目标屏幕：菜单可见性与命名")
check(!NotchScreenTarget.shouldShowMenu(screenCount: 1), "单屏不出现子菜单")
check(NotchScreenTarget.shouldShowMenu(screenCount: 2), "多屏才出现")
check(NotchScreenTarget.baseName("Built-in Retina Display", isBuiltin: true) == "内置显示器",
      "内建屏用统一名，不暴露系统语言下的型号名")
check(NotchScreenTarget.baseName("DELL U2720Q", isBuiltin: false) == "DELL U2720Q",
      "外接屏沿用型号名")
check(NotchScreenTarget.baseName("", isBuiltin: false) == "显示器", "名字为空也不出现空行")
check(NotchScreenTarget.dedupe("DELL U2720Q", index: 0) == "DELL U2720Q", "首个不补序号")
check(NotchScreenTarget.dedupe("DELL U2720Q", index: 1) == "DELL U2720Q（2）",
      "第二块同型号补序号，菜单里能区分")

// MARK: - 图标动效（logo 与状态灯合一）
//
// 这里只断言「参数常量」，不断言动画本身（动画无法脱离界面验证）。
// 其中前两条是 review 时最容易在改动里丢掉的约束：C 形必须是长弧（开口朝下）、
// 追逐光轨必须完全脱离底弧带宽 —— 后者是 demo 原样落地的真 bug：光轨 r250 落在
// 底弧（r185 + 132 描边 → 覆盖 r119–251）里，两者同色，18pt 下「工作中」看起来是静止的。

let arcOuterEdge = LogoMotionMetrics.arcRadius + LogoMotionMetrics.arcStroke / 2

for (light, expected) in [(TaskLight.gray, LogoMotionState.idle),
                          (.green, .done), (.yellow, .working), (.red, .waiting)] {
    eq(LogoMotionState(light: light), expected, "\(light.rawValue) 映射到 \(expected)")
}

check(LogoMotionMetrics.arcSweep > 180,
      "底弧是长弧（扫过 \(Int(LogoMotionMetrics.arcSweep))° > 180°），C 形开口朝下")
check(LogoMotionMetrics.orbitRadius > arcOuterEdge,
      "追逐光轨（r\(Int(LogoMotionMetrics.orbitRadius))）脱离底弧带宽（r\(Int(arcOuterEdge))），否则会被盖住")
check(LogoMotionMetrics.arcOpacity < 1,
      "底弧压暗到 \(LogoMotionMetrics.arcOpacity)，同色光轨才看得出来")
check(LogoMotionMetrics.orbitLeadWidth > LogoMotionMetrics.orbitMidWidth
      && LogoMotionMetrics.orbitMidWidth > LogoMotionMetrics.orbitTailWidth,
      "光轨头 > 中 > 尾（头亮中弱尾淡）")
check(LogoMotionMetrics.orbitMidOpacity > LogoMotionMetrics.orbitTailOpacity,
      "中层比尾层亮")

let lead = LogoMotionMetrics.leadTrim
let mid = LogoMotionMetrics.midTrim
let tail = LogoMotionMetrics.tailTrim
check(lead.from == 0 && lead.to > 0 && tail.to < 1,
      "三段光轨都落在 (0,1) 内，且头段从 0 起")
check(lead.from == 0 && mid.from < lead.to && mid.from < tail.from && tail.to < 1,
      "三段起点递增、头与中重叠成彗尾，且都不越过起点（demo 原 dash 值 111.5 / 92.2+62.2 / 165.1+30.0）")
check(LogoMotionMetrics.leadTrim.to > LogoMotionMetrics.midTrim.to - LogoMotionMetrics.midTrim.from,
      "头段比中段长（长拖尾锥形）")

let palette = [LogoMotionState.idle, .done, .working, .waiting, .error].map { $0.color }
eq(Set(palette).count, 4, "五态共用四支颜色（两种红同一支）")
check(palette.allSatisfy { $0.hasPrefix("#") && $0.count == 7 }, "五态颜色都是 #RRGGBB")
check(LogoMotionMetrics.enterDuration > 0 && LogoMotionMetrics.colorDuration > 0,
      "进出场与换色时长都是正数")

// MARK: - LogoMotion：红灯两态（等你确认 / 异常）与动效启停

// 回归点 1：早前把「异常」挤进 `.waiting`，`animated` 又直接返回 `redBlinking`，
// 于是 redBlinking=false 的异常红**完全不播动画**——与设计稿「异常＝单圈 2.4s 慢脉冲」相反。
eq(LogoMotionState(light: .red, redBlinking: true), .waiting, "红灯 + 要打断你 → 等你确认")
eq(LogoMotionState(light: .red, redBlinking: false), .error, "红灯 + 轮次异常 → 异常（异常也必须播动效）")
eq(LogoMotionState(light: .gray, redBlinking: false), .idle, "红灯标志不影响非红状态的映射")
eq(LogoMotionState.idle.pulse, .none, "空闲不脉冲（它有自己的呼吸 / 涟漪）")
eq(LogoMotionState.working.pulse, .none, "工作中不脉冲（它有自己的光轨）")
eq(LogoMotionState.waiting.pulse, .double, "等你确认 = 双圈错相脉冲")
eq(LogoMotionState.error.pulse, .single, "异常 = 单圈慢脉冲")
eq(Set([LogoMotionState.waiting.color, LogoMotionState.error.color]).count, 1,
   "两种红共用同一支颜色，只靠脉冲圈数与频率区分")
check(LogoMotionMetrics.errorWaveDuration > LogoMotionMetrics.waitingWaveDuration,
      "异常（\(LogoMotionMetrics.errorWaveDuration)s）比等你确认（\(LogoMotionMetrics.waitingWaveDuration)s）慢：提示但不催")
check(LogoMotionMetrics.errorWavePeakOpacity < LogoMotionMetrics.alertWaveStartOpacity,
      "异常脉冲峰值透明度更低（\(LogoMotionMetrics.errorWavePeakOpacity) < \(LogoMotionMetrics.alertWaveStartOpacity)）")
check(LogoMotionMetrics.errorBarBright < LogoMotionMetrics.alertBarBright,
      "异常竖条不改位置，只做透明度呼吸（\(LogoMotionMetrics.alertBarDim)↔\(LogoMotionMetrics.errorBarBright)）")

// 回归点 2：循环动画只在视图首次出现（onAppear）时启动，而视图重建靠 `.id` 触发。
// 早前只写 `.id(state)`：任务从「等你确认」变成「异常」时 state 仍是 `.waiting`、`.id` 没变 →
// 视图不重建 → onAppear 不再跑 → 动画既不会启动也不会停止。
let keyWaitingAnimated = LogoMotionBadge.motionKey(state: .waiting, animated: true)
let keyWaitingStatic = LogoMotionBadge.motionKey(state: .waiting, animated: false)
check(keyWaitingAnimated != keyWaitingStatic,
      "同一状态下「播动效 / 不动效」是两个不同的 id，否则标志翻转不重建视图")
eq(LogoMotionBadge.motionKey(state: .waiting, animated: true), keyWaitingAnimated,
   "同一个 (state, animated) 得到同一个 id——数据刷新不会把动画重头播")
check(LogoMotionBadge.motionKey(state: .error, animated: true) != keyWaitingAnimated,
      "两种红各有各的 id")

// 空闲振幅（DESIGN.md §8 方案 A）：28pt 下描边会落到亚像素，振幅不够就等于「看起来静止」
let idleRingTravelRadius = (LogoMotionMetrics.idleRingEndScale - LogoMotionMetrics.idleRingStartScale)
    * LogoMotionMetrics.idleRingRadius * 28 / LogoMotionMetrics.design
check(idleRingTravelRadius * 2 >= 3,
      "28pt 下空闲涟漪直径变化 \(String(format: "%.2f", idleRingTravelRadius * 2))pt ≥ 3pt，肉体可辨")

// MARK: - 页脚额度读数（已用 / 总量）

// 页脚只有一行，读数必须先压长度，否则会把右侧的铃铛 / 齿轮挤跑（用户反馈 ③）
eq(UsageAPI.footerCredits(1240), "1,240", "四位数加千分位")
eq(UsageAPI.footerCredits(2000), "2,000", "四位数加千分位")
eq(UsageAPI.footerCredits(12345678), "1,234.6 万", "≥1 万缩写到万、保留 1 位小数")
eq(UsageAPI.footerCredits(999999999), "10.0 亿", "≥1 亿缩写到亿（四舍五入到 10.0）")
eq(UsageAPI.footerReadout(used: 1240, total: 2000).combined, "1,240 / 2,000", "读数格式为「已用 / 总量」")
eq(UsageAPI.footerReadoutPlaceholder.combined, "— / —", "取不到数据时用占位符，不写 0")

// 防跑版阶梯（DESIGN.md §3.1–3.3）：三档实测的「放得下 / 放不下」分界在 15 与 21 字符之间
check(!UsageAPI.footerReadoutNeedsTrim(
        UsageAPI.footerReadout(used: 1240, total: 2000).combined),
      "常规读数（1,240 / 2,000）带「已用」也放得下")
check(!UsageAPI.footerReadoutNeedsTrim(
        UsageAPI.footerReadout(used: 1_000_000_000, total: 1_000_000_000).combined),
      "十亿级读数（10.0 亿 / 10.0 亿）带「已用」仍放得下")
check(UsageAPI.footerReadoutNeedsTrim(
        UsageAPI.footerReadout(used: 12_345_678, total: 20_000_000).combined),
      "千万级读数（1,234.6 万 / 2,000.0 万）放不下 → 降级去掉「已用」")
check(UsageAPI.footerReadoutNeedsTrim("999,999,999 / 1,000,000,000"),
      "未缩写的最长原值也必须触发降级")

// MARK: - v2 刻度锁定（DESIGN.md §7.1 / §7.4）

section("v2 刻度锁定（页脚 / 面板 / chip）")

// 页脚是全局最易「改了大面板漏了小面板」的地方：两种形态共用同一张刻度表，
// 这里把设计稿的落地值逐项钉住，任何静默漂移都会在这段失败。
// 两种显示模式共用同一张刻度表（用户反馈 ①：原先刘海单行 20、悬浮两行 34，版式不统一）
let footerM = FooterMetrics()

eq(footerM.height, 34, "页脚总高 34")
eq(footerM.padV, 6, "上下内边距 6")
eq(footerM.rowHeight, 14, "第 1 行行高 14")
eq(footerM.rowSpacing, 4, "两行行距 4")
eq(footerM.barHeight, 4, "进度条高 4")
eq(6 + footerM.rowHeight + footerM.rowSpacing + footerM.barHeight + 6,
   footerM.height, "总高 = padding 6 + 第 1 行 14 + 行距 4 + 进度条 4 + padding 6 = 34")
eq(footerM.quotaFont, 10, "额度读数 10pt")
eq(footerM.iconFont, 10.5, "图标 10.5pt")
eq(footerM.countFont, 10, "未读数 10pt")
eq(footerM.segWidth, 17, "周期胶囊段宽 17")
eq(footerM.segHeight, 14, "周期胶囊段高 14")
eq(footerM.segFont, 9.5, "周期胶囊段内文字 9.5pt")
eq(footerM.hitWidth, 32, "齿轮热区宽 32")
eq(footerM.hitHeight, 22, "图标热区高 22")
eq(footerM.bellHitWidth, 22, "铃铛热区宽 22（比齿轮窄，对应稿 x=185 / x=219）")
eq(footerM.clusterSpacing, 2, "铃铛与齿轮间距 2")
eq(footerM.dividerWidth, 1, "分区竖线 1pt")
eq(footerM.dividerHeight, 16, "分区竖线高 16")
eq(footerM.percentWidth, 36, "百分比占位固定 36（62% / 61.7% / 100% 不推挤进度条）")

// 第 2 行收口：进度条 + 百分比必须在左侧额度区内结束，不得跨进图标簇那一列
// （用户反馈 ①：「百分比跑到设置按钮下面」）
eq(footerM.clusterWidth, 62, "图标簇总宽 62（竖线留白 6 + 铃铛 22 + 间距 2 + 齿轮 32）")
eq(footerM.quotaWidth(contentWidth: 252), 182, "252 内容宽下额度区宽 182（稿分隔线 x=179 同量级）")
check(footerM.quotaWidth(contentWidth: 252) + footerM.clusterWidth + footerM.quotaGap == 252,
      "额度区 + 图标簇 + 最小间距 = 内容宽：百分比右边界不越过分区竖线")
check(footerM.quotaWidth(contentWidth: 40) == 0, "窄面板下额度区宽夹到 0，不出现负宽")

// 面板 / 刘海刻度（§7.1 v2 表）
eq(NotchLayout.horizontalPadding, 14, "面板内边距左右 14")
eq(NotchLayout.listSpacing, 4, "行距 4")
eq(NotchLayout.blockSpacing, 8, "区块间距 8")
eq(NotchLayout.bottomPadding, 14, "底部留白 14（> 手柄命中区，不盖页脚热区）")
eq(FloatingMetrics.panelHPadding, 14, "悬浮面板内边距左右 14")
eq(FloatingMetrics.panelBottomPadding, 14, "悬浮面板底部留白 14")
eq(FloatingMetrics.chipSize, 36, "图标 chip 36×36")
eq(FloatingMetrics.chipCorner, 10, "chip 圆角 10")
check(FloatingMetrics.chipSize < FloatingMetrics.iconBox,
      "chip 不得改变 44pt 命中盒")

// MARK: - 更新说明（Release 正文 → 新增 / 优化 / 修复）

section("更新说明解析（Release 正文 → 三组）")

// 夹具模仿 GitHub releases.atom：正文是「XML 里再套一层 HTML 实体」
let notesEntry = #"""
<entry><title>Comate HUD v1.4.6</title>
<link href="https://github.com/likelu9/comate-hud/releases/tag/v1.4.6"/>
<content type="html">&lt;ul&gt;
&lt;li&gt;✨ 新增 新增「面板置顶屏幕」选项&lt;/li&gt;
&lt;li&gt;✨ 新增 新增未读角标一键清除&lt;/li&gt;
&lt;li&gt;⚡ 优化 优化任务列表滚动流畅度&lt;/li&gt;
&lt;li&gt;🔧 修复 修复深色下分隔线偏亮&lt;/li&gt;
&lt;li&gt;🔧 修复 修复 A &amp;amp; B 同时出现时的闪烁&lt;/li&gt;
&lt;li&gt;🏗 架构 内部重构（不在三组内，应跳过）&lt;/li&gt;
&lt;/ul&gt;
&lt;p&gt;&lt;strong&gt;系统要求&lt;/strong&gt;：macOS 12.0+ · Apple Silicon &amp;amp; Intel&lt;/p&gt;
&lt;p&gt;&lt;strong&gt;首次打开&lt;/strong&gt;：未签名，需手动放行&lt;/p&gt;
</content></entry>
"""#

let notes = UpdateChecker.parseNotes(fromEntry: notesEntry)
eq(notes.added, ["新增「面板置顶屏幕」选项", "新增未读角标一键清除"], "✨ 新增 → 「新增」组") 
eq(notes.improved, ["优化任务列表滚动流畅度"], "⚡ 优化 → 「优化」组")
eq(notes.fixed, ["修复深色下分隔线偏亮", "修复 A & B 同时出现时的闪烁"], "🔧 修复 → 「修复」组，且两层实体都解开")
check(!notes.isEmpty, "三组都有内容")
eq(notes.groups.map(\.title), ["新增", "优化", "修复"], "组序固定为 新增 → 优化 → 修复")
eq(notes.groups.map(\.items.count), [2, 1, 2], "每组条目数")

// 说明区只展示三组；正文里其余段落（系统要求 / 首次打开）不能被抓进来
check(notes.added.allSatisfy { !$0.contains("系统要求") && !$0.contains("macOS") },
      "正文本体（系统要求 / 首次打开）不混入说明条目")
check(!notes.fixed.contains { $0.contains("架构") }, "「架构」不在设计稿三组内 → 跳过")

// 标签只在行首生效：正文中间出现「修复」二字不能被误判
let midLine = UpdateChecker.classifyNoteLine("新增 修复了上次遗留的问题")
eq(midLine?.group, UpdateNoteGroup.added, "行首是「新增」时，正文里的「修复」不抢组")
check(UpdateChecker.classifyNoteLine("这条没有标签前缀") == nil, "无标签前缀 → 不归组")
check(UpdateChecker.classifyNoteLine("🔧 修复") == nil, "只有标签没有文案 → 不产出空条目")

// 空组不占位：老 Release（v1.4.3 那种正文里没有 li）→ notes 为空，窗口走兜底文案
let legacyEntry = #"<entry><content type="html">&lt;p&gt;本次无对外可见变化&lt;/p&gt;</content></entry>"#
check(UpdateChecker.parseNotes(fromEntry: legacyEntry).isEmpty,
      "无 li 的旧 Release → 空说明（窗口需有兜底，不能留白 100pt）")
check(UpdateChecker.parseNotes(fromEntry: "<entry></entry>").isEmpty, "无 content → 空说明，不崩")

// 顺带锁住 feed 主解析：版本号与说明一次性拿回来
eq(UpdateChecker.parseLatest(feed: notesEntry)?.version, "1.4.6", "从 entry 取到版本号")
eq(UpdateChecker.parseLatest(feed: notesEntry)?.notes.added.count, 2, "parseLatest 同时带回说明")

// MARK: - 更新窗形态

section("更新窗四态解析")

// 顺序即语义：已知的新版本不被一次重新检查的中间态盖掉
eq(UpdatePromptState.resolve(hasUpdate: true, isChecking: true, failed: true, checked: true), .available,
   "有新版优先级最高")
eq(UpdatePromptState.resolve(hasUpdate: false, isChecking: true, failed: true, checked: true), .checking,
   "检查中优先于失败")
eq(UpdatePromptState.resolve(hasUpdate: false, isChecking: false, failed: true, checked: true), .failed,
   "查过且失败 → 失败态")
eq(UpdatePromptState.resolve(hasUpdate: false, isChecking: false, failed: false, checked: true), .latest,
   "查过且无更新 → 已是最新")
eq(UpdatePromptState.resolve(hasUpdate: false, isChecking: false, failed: false, checked: false), .checking,
   "从没查成功过 → 检查中，不能谎报「已是最新」")

// 标题文案是设计稿三态三标题，钉住免得后续改文案漏一处
eq(UpdatePromptState.available.windowTitle, "Comate HUD 有可用更新", "有新版标题")
eq(UpdatePromptState.checking.windowTitle, "Comate HUD 有可用更新", "检查中沿用「有可用更新」标题（同一段动作）")
eq(UpdatePromptState.latest.windowTitle, "Comate HUD 已是最新", "已是最新标题")
eq(UpdatePromptState.failed.windowTitle, "Comate HUD · 检查更新失败", "失败标题")

// MARK: - 「已是最新 · 多久前」

section("更新检查相对时间")

let checkBase = Date(timeIntervalSince1970: 1_700_000_000)
eq(UpdateChecker.relativeDescription(since: nil, now: checkBase), "", "没查过不编时间")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(30)), "刚刚", "一分钟内")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(120)), "2 分钟前", "分钟级")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(7200)), "2 小时前", "小时级")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(3 * 86400)), "3 天前", "天级")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(59)), "刚刚", "59 秒仍在刚刚")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(3600)), "1 小时前", "整一小时")
eq(UpdateChecker.relativeDescription(since: checkBase, now: checkBase.addingTimeInterval(-100)), "", "时间戳在未来（改过系统时间）不显示负数")

// MARK: - 汇总

print("\n———————————————")
if failures == 0 {
    print("✅ \(checks) 项断言全部通过")
    exit(0)
} else {
    print("❌ \(failures)/\(checks) 项断言失败")
    exit(1)
}
