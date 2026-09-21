# 悬浮窗接入模型用量

## 接口（已实测跑通；需 `Cookie: wps_sid=<keychain>` + `Referer: https://comate.wps.cn/web/`）
- **限额**：`GET /llmproxy/v1/user/token-usage`
  → `data.credits_usage.periods[]` = `{credits_limit, credits_used, credits_rest, period_type: daily|monthly}`
  实测：日 22614.30/30000、月 82239.48/85000
- **明细**：`GET /api/coserve/v1/usage/details?model_type=public&start_time=<ISO+08:00>&end_time=…&page=1&page_size=100`
  → `data.items[]` = `{session_id, title, model, total_credits, total_tokens, time(UTC), event_type}`，`data.total` 用于算页数
- `model_type` 只能 `public`（`private` 全 0 点，`all` 返回空）；`page_size` 实测 100 可用、500 被压到 20

## 关联与口径
- `items[].session_id` == `ComateTask.id`（本地 = `chat_sessions.id`，实测「制作技能」= 809f7175… = 1.68 点；云端 id 实现时核对）
- 区间与归日一律 **UTC+8**（`+08:00`），"今日" = 北京时间当日
- 单任务智点 = `total_credits` 按 `session_id` 求和

## 展示决策（已确认）
- **行内只显示智点**：有当日记录 → `今日 1.68 点`；无 → 近 30 天累计 `30天 45.6 点`；仍无 → `—`
- **左下角**：默认日限额百分比 `日 75%`，点击切换 `月 97%`，选择持久化到 UserDefaults；hover 显示已用/总额/剩余
- 原 `今日 N 次对话` 让位（如需保留可后加）

## 刷新策略
- 单 60s 定时器：限额（1 请求）+ 当日明细（1 请求）
- 每 5 分钟或启动时：近 30 天回填（串行分页 ≈24 请求，失败保留旧缓存）
- 后台队列取数、主线程更新；值未变不刷新 @Published（防 SwiftUI 抖动）

## 风险
- 接口未文档化，可能变更/限流 → 任何失败静默降级为占位符，绝不崩
- 30 天回填请求量（80 条/天）→ 仅启动 + 5 分钟一次，串行、单页失败即中止本轮
- 云端任务 session_id 若对不上 → 该行回落占位符
- 跨日错位 → 固定 +08:00，不依赖本机时区

## 验证
- 单测：归日、30 天聚合、行内三态、百分比与切换持久化（用真实响应做 fixture）
- 实拍：左下角 `日 75%` → 点击变 `月 97%` → 重启仍为月；「制作技能」行显示 `今日 1.68 点`（与网页一致）
- 交叉校验：各行今日点数之和 ≈ 日限额已用（允许分钟级漂移）
- 断网/坏 sid：面板正常，仅显示占位符
