# ComateNotch 待优化清单

**版本**: v1.4.5 (build 14)  
**日期**: 2026-09-28  

---

## 已完成 ✅

### Phase1 - 阻塞项修复
- Info.plist 添加 NSAppleEventsUsageDescription（旁白权限）
- Info.plist 添加 CFBundleIconFile 指向 AppIcon.icns
- 版本号升级至 1.1.0 (build 2)
- NSScreen.main! 强制解包改为 optional 兜底（虚拟屏幕几何）
- 黄灯标签「思考中」→「工作中」

### Phase2 - Bug 修复
- Keychain 读取移出主线程（fetchWpsSid → readWpsSidFromKeychain 静态 + wpsSid(forceRefresh:) 缓存）
- NSLock 串行化并发启动读取（避免首次弹出 3 个授权框）
- 401 路径使用 wpsSid(forceRefresh: true) 重读
- mergeRecentTasks(local:cloud:) 合并逻辑复用，云端刷新回填 credits30d

### Phase3 - 图标
- 方案 B：深色 squircle 底 + Comate logo 居中 + 底部红黄绿三灯
- 生成 AppIcon.icns (240KB)，包含 16x16 到 1024x1024 全尺寸

### Phase4 - 构建与分发
- build.sh 支持 universal 双架构 (arm64 + x86_64) + ad-hoc 签名
- DMG 打包完成 (932KB)，含 Applications 符号链接 + 安装说明

### Phase5 - 客户端增强（1.4.1）
- 更新检测：读 GitHub Releases 的 latest tag，与本地版本语义比较；设置按钮与菜单项「检测到新版 vX.Y.Z」同时亮红点（菜单红点走勾选列），点该项即记为已读并跳发布页——同一版本不再提示，出现更新版本时红点恢复（`Sources/UpdateChecker.swift`）
- 开机自启：写用户级 LaunchAgent（`~/Library/LaunchAgents/com.wpscomate.hud.plist`），首次启动默认开启，菜单里可勾选切换（`Sources/LaunchAtLogin.swift`）
- 单实例保护：同 bundle id 已在运行则请它把面板重新置前，新实例直接退出，避免两份 HUD 叠加与双份活跃上报（`Sources/AppDelegate.swift`）
- 技术债：任务模型拆到 `TaskModel.swift`，面板布局公式拆到 `NotchLayout.swift`，新增 `test.sh`（47 项断言）
- 文档防漂移：新增 `scripts/check-docs.sh` 并在 `build.sh` 里强制校验（版本号同源 / SOURCES 完整 / 官网不硬编码）

### Phase6 - 1.4.2 发布
- 更新源改用 `releases.atom`：REST 未鉴权限额按 IP 计（60/时），共享出口 IP 实测已 403
- `scripts/check-docs.sh` 的 DMG 校验加时序例外：正在构建的版本其 DMG 由本次构建产出，不报错
- 发布 1.4.2：Info.plist / TODO.md / versions.json 三处版本号同步

### Phase7 - 1.4.4 凭据自持与登录可见化
- **凭据来源整体切换**：不再读 Comate 桌面端写在 Keychain 的 `wps_sid`（要 fork `security`、别人机器首次弹授权框、坏了没人知道），改为 HUD 自己用内嵌 WKWebView 登录一次，`wps_sid` 存在自己的 cookie store 里（`Sources/AuthSession.swift`）
  - 实测：cookie store 必须有活着的 WKWebView 实例才读得到（无实例时 `getAllCookies` 恒返回空）；常驻一个离屏实例 +21MB，不拉子进程；cookie 按 bundle id 隔离，读不到 Safari / WPS Office / Comate 桌面端
  - 登录成功的判据 = 真的打通 o.wpsgo.com（身份）与 comate.wps.cn（额度）两条链路，而不是「cookie 里出现了 wps_sid」——避免假成功
- **登录窗口**（`Sources/LoginWindow.swift`）：独立 NSWindow + 复用常驻 WKWebView；打开时先查自有凭据，能复用就直接恢复、不弹窗（观感是「点一下就恢复」）
- **首次启动引导**：未登录时自动弹一次登录窗口（用户关掉后不再自动弹），老用户升级后正好收到一次引导
- **失败可见化**：面板额度位在未登录 / 失效时换成可点的登录引导（原来只有一个「—」）；右键菜单账号组置顶并在失效时亮红点；可退出登录
- **上报策略**：401/403 的固定静默 6 小时改为阶梯退避（30 秒 → 1 分钟 → 5 分钟 → 15 分钟 → 1 小时封顶）；新增日内每 2 小时补报当天桶
- `test.sh` 断言 47 → 80 项（新增 sid 合法性、失效重试判定、退避阶梯）

---

### Phase8 - 1.4.5 更新提示独立小窗（v2 设计稿落地）
- 新增 `Sources/UpdateWindow.swift`：`420×320` 不可缩放独立窗、标题随形态变、四态（有新版 / 检查中 / 已是最新 / 检查失败），说明区按 新增 · 优化 · 修复 三组圆点列出（**区块定高 100pt**，超出裁掉 —— 四态按钮基线才对得齐）
- changelog **不拉 `versions.json`**：官网那份在 `comate.wpsgo.com` 下、无会话 **403**，客户端读不到；改从**已有**的 `releases.atom` 的 Release 正文解析（`release.sh` 正是用它生成 `<ul><li>…</li></ul>`，与官网同源、同一套 type 映射）→ 不新增端点、不加缓存。旧 Release（v1.4.3 之前无条目）落回「本次更新的详细说明请见发布页」
- 入口接线（依据 update.html 的关系表）：菜单项「检测到新版 vX」→ **开窗**（无新版则就地检查，标题变「正在检查更新…」）；设置窗口通用页**就地五态**（尚未检查 / 检查中 / 已是最新 · 多久前 / 检测到新版 / 检查失败），「检测到新版」**整行可点**开窗、右侧只留 `chevron.right`
- **ack 口径收敛**：只有「跳过此版本（不再提示）」会 `acknowledgeUpdate()`；两个下载入口与「稍后」都不 ack —— 下载只负责把用户送到发布页，那时他还没做任何「我处理完了」的声明（设置行原先两次 ack 已一并去掉）
- 品牌色收敛到 `HUDDesign` 单一来源（设置窗与更新窗共用 `#00D4AA` / 深墨 `#0F0F11` / 禁用 40%），消掉两处各写一遍的隐患
- `test.sh` 203 → 235 项断言（更新说明解析 15 项 / 四态解析 9 项 / 相对时间 8 项）

### Phase9 - 1.4.6 全局 UI 按稿对齐（六项）
- **额度区两模式统一**：v1 那版「刘海单行 20pt / 悬浮两行 34pt」分叉删除，两模式共用一套 `FooterMetrics`（高 `34` = 6 + 14 + 4 + 4 + 6）与同一个 `HUDUsageFooter`；第 2 行（进度条 + 百分比）按 `quotaWidth(contentWidth:)` 收口在**左侧额度区**内，百分比不再滑到齿轮列下（分区分隔线 / 铃铛 / 齿轮坐标恒定，`252` 内容宽下额度区 `182`）
- **齿轮直开设置窗**：两种模式下点齿轮不再展开菜单，直接开设置窗（检测到新版时落「通用」页）；`HUDContextMenu`（11 组）与两态右键菜单**整体下线** —— 菜单里的「退出 Comate HUD」→ 关于页底部静默文字链接，「打开 WPS Comate」→ 账号页操作组一行
- **更新红点链路**：齿轮右上角 5pt 红点 → 设置窗落「通用」页 → 侧栏「通用」项右侧红点（稿 `.nav-dot`）→ 「更新」行绿字「检测到新版 vX」+ `chevron.right`（整行可点开更新小窗）；三处共用 `UpdateDotBadge`（`dot.update` 5pt + `dot.update-ring` 1pt 分离环，进 `HUDDesign`）
- **设置窗按稿重写**（`settings.html` 内联样式 = 第二阶段权威）：窗口 `560×480`（内容区 `452 = 480 − 28`，系统标题栏）、侧栏 `148`、导航项 `32`、**选中态 `accent.soft` 底 + `text.primary`(500) + 图标 `accent.hover`**、页标题 `14/600` + 副标 `9pt`、组标题 `12/600`、行高 `38`、行内 `6/10`、控件高 `24`、开关 `34×20`（钮 16 纯白）、单选 `14`、下拉 `24/min 132`、主/次/中性三档按钮、警示条 `waiting-soft` + `line.warn`
- **关于页**：图标 `88`（`radius.20`，投影 `0 10 14 / 55%`，内描边白 `9%`）、产品名 `22/700 rounded` 纯白、版本胶囊 `10.5/500`（底/描边白 `7%`、字白 `58%`）、主张 `13/600 text.primary`（**不着紫**）、描述 `12pt` 白 `60% max 300`、四态图例卡（`radius.14` + `surface.card`，色点 `8pt` + 同色 `3.5` 光晕）、特性 3 行（勾选 `14pt accent.soft` 圆底 + `accent.hover`）、署名（强调段白 `88%` + 品牌绿下划线）、主按钮 `150×30`、文字链接；紫色氛围光只此一处（`circle 190`、`560×320`、`offset y −120`）
- **悬浮图标 chip 描边补四档**：常态 `8%` / hover `10%` / 展开中 `14%`（原先固定 `8%`，展开态描边偏浅）；底色 `6/10/12%` 不变
- **更新行回归稿**：「尚未检查」是稿里的两行骨架（检查更新 + 手动触发一次版本检查 · 当前 vX + 中性按钮），其余各态收成单行状态文案（检查中 = 中性 5pt 点、已最新 = 绿勾、有新版 = 红点 + 图标 + 绿字 + chev），失败态为兜底（图标 + 文案 + 重试）
- `test.sh` 226 项断言全绿（新增页脚几何 17 项：总高 / 行高 / 行距 / 字号 / 胶囊段 / 热区 / 竖线 / 百分比占位 / 图标簇 62 / 额度区 182 / 窄面板夹到 0）；`build.sh` exit 0（universal + DMG 2.4M）；`check-docs.sh` exit 0；官网自检 16/16

## 待优化 📋

### P0 - 高优先级

| # | 项目 | 说明 | 工作量 |
|---|------|------|--------|
| 1 | **签名证书** | 当前 ad-hoc 签名，用户需在「系统设置 → 隐私与安全性 → 安全性」中手动放行（新版 macOS 右键打开已不再提供「打开」选项）。申请 Apple Developer 证书后可正式签名 + 公证 | 1天 |
| 2 | **崩溃上报** | 无崩溃日志收集。建议接入 Sentry 或自建崩溃上报 | 1天 |

### P1 - 中优先级

| # | 项目 | 说明 | 工作量 |
|---|------|------|--------|
| 3 | **多显示器适配** | 当前固定在主显示器刘海区域，多显示器用户需支持跟随/固定选择 | 0.5天 |
| 4 | **菜单栏图标** | 当前 LSUIElement 隐藏了 Dock 图标，但菜单栏无入口。可添加 NSStatusItem 作为常驻入口 | 1天 |

### P2 - 低优先级

| # | 项目 | 说明 | 工作量 |
|---|------|------|--------|
| 5 | **面板动画** | 展开/收起无过渡动画，可添加弹簧动画提升体验 | 0.5天 |
| 6 | **设置面板** | 无可视化设置，用户无法调整刷新频率、热区位置等 | 1天 |
| 7 | **国际化** | 当前中文硬编码，如需国际化需抽离字符串 | 0.5天 |
| 8 | **日志系统** | 当前 print 日志，建议接入 os_log 或 SwiftyBeaver | 0.5天 |

---

## 技术债务

- `ComateStore.swift` 957 行：任务模型（`TaskLight` / `RedKind` / `ComateTask`）已拆到 `TaskModel.swift`。再拆「模型用量」「云端任务」两段需要把一批 `private` 状态放宽为 internal —— Swift 扩展不能新增存储属性，状态只能留在原文件，收益与风险需要单独评估
- `NotchRootView.swift` 624 行：布局公式与常量已拆到 `NotchLayout.swift`；`ComateLogo` / `ComateOfficialPath1,2` / `StatusLight` / `NotchShape` / `ComateTaskRow` / `ComatePlusButton` 等独立视图仍混在同一文件，可再拆
- `test.sh` 已覆盖版本比较 / 布局公式 / 状态灯判定 / 凭据校验 / 上报退避阶梯 / v2 刻度 / 页脚几何 / 更新说明解析 / 更新窗四态（226 项断言）；仍缺 UI 层与数据读取层（SQLite 查询、会话日志解析）的自动化覆盖

---

## 文件清单

| 路径 | 说明 |
|------|------|
| `ComateNotch/build/ComateHUD.app` | 构建产物（universal binary） |
| `ComateNotch/dist/ComateHUD-<版本>.dmg` | 分发包（版本号取自 Info.plist） |
| `ComateNotch/Resources/AppIcon.icns` | 应用图标 |
| `ComateNotch/build.sh` | 构建脚本（双架构 + 签名 + 文档校验） |
| `ComateNotch/test.sh` | 纯逻辑测试（不启动 UI） |
| `ComateNotch/scripts/check-docs.sh` | 文档 / 版本号一致性校验 |
