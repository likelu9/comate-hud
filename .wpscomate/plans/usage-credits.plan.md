# 悬浮窗接入模型用量

## 接口（已实测跑通）
- **限额**：`GET /llmproxy/v1/user/token-usage` → `data.credits_usage.periods[]` = `{credits_limit, credits_used, credits_rest, period_type: daily|monthly}`。实测 日 22614.30/30000、月 82239.48/85000
- **明细**：`GET /api/coserve/v1/usage/details?model_type=public&start_time=<ISO+08:00>&end_time=…&page=1&page_size=100` → `data.items[]` = `{session_id, title, total_credits, total_tokens, time(UTC)}`，`data.total` 算页数
- `model_type` 只能 `public`；`page_size` 上限实测 100（传 500 被压到 20）

## 认证方案（其他用户可用性 —— 重点）
- 凭据来源 = macOS keychain 的 `credential_wps_sid`，由 **Comate 桌面客户端**登录时写入（`go-keyring-base64`）。
- **与浏览器登录状态无关**：用户没在浏览器登录 comate.wps.cn 也照样能取，因为 sid 来自桌面端而非浏览器 cookie。
- 前提 = 装了 Comate 桌面端并已登录 —— 这本来就是这个 app 的硬前提（它读的就是桌面端的本地 DB 与会话日志）。
- 与现有「未读消息 / 云端任务」两个接口复用同一凭据，**不新增权限、不新增弹窗**。
- 降级：读不到 sid → 左下角显示 `用量 —`（hover 说明「未登录 Comate 桌面端」）；sid 失效/401 → 同样降级 + 退避 5 分钟后再试，不反复打接口、不崩、不影响面板其他功能。
- 实现时核对：keychain 中 `credential_wps` 前缀的实际条目命名（是否所有账号都叫 `credential_wps_sid`）与多账号场景。

## 展示（已确认）
- 行内统一显示**近 30 天智点**：`30天 45.6 点`；30 天内无记录 → `—`（不再区分当日）
- 左下角：默认日限额百分比 `日 75%`，点击切换 `月 97%`，选择持久化到 UserDefaults；hover 出已用/总额/剩余
- 原 `今日 N 次对话` 让位

## 刷新策略
- 60s：限额（1 请求）
- 5 分钟或启动时：近 30 天回填（串行分页 ≈24 请求，失败保留旧缓存）
- 后台队列取数、主线程更新；值未变不刷新 @Published

## 风险
- 接口未文档化 → 任何失败静默降级为占位符
- 30 天回填请求量（80 条/天）→ 5 分钟一次、串行、单页失败即中止本轮
- 云端任务 session_id 若对不上 → 该行回落占位符
- 跨日错位 → 固定 +08:00，不依赖本机时区

## 验证
- 单测：归日、30 天聚合、占位符、百分比与切换持久化、降级分支（真实响应做 fixture）
- 实拍：左下角 `日 75%` → 点击 `月 97%` → 重启仍为月；「制作技能」行显示 `30天 x 点`
- 交叉校验：各行 30 天点数之和与限额已用值量级一致
- 坏 sid / 断网：面板正常，仅显示 `用量 —`
