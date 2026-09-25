# ComateNotch 待优化清单

**版本**: v1.4.3 (build 12)  
**日期**: 2026-09-25  

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

---

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
- `test.sh` 已覆盖版本比较 / 布局公式 / 状态灯判定（47 项断言）；仍缺 UI 层与数据读取层（SQLite 查询、会话日志解析）的自动化覆盖

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
