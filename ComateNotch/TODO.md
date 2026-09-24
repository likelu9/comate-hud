# ComateNotch 待优化清单

**版本**: v1.1.0  
**日期**: 2026-09-22  

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

---

## 待优化 📋

### P0 - 高优先级

| # | 项目 | 说明 | 工作量 |
|---|------|------|--------|
| 1 | **签名证书** | 当前 ad-hoc 签名，用户需在「系统设置 → 隐私与安全性 → 安全性」中手动放行（新版 macOS 右键打开已不再提供「打开」选项）。申请 Apple Developer 证书后可正式签名 + 公证 | 1天 |
| 2 | **自动更新** | 当前无自更新机制。可接入 Sparkle 框架实现版本检查与增量更新 | 2天 |
| 3 | **崩溃上报** | 无崩溃日志收集。建议接入 Sentry 或自建崩溃上报 | 1天 |

### P1 - 中优先级

| # | 项目 | 说明 | 工作量 |
|---|------|------|--------|
| 4 | **多显示器适配** | 当前固定在主显示器刘海区域，多显示器用户需支持跟随/固定选择 | 0.5天 |
| 5 | **登录项** | 无开机自启。需添加 SMLoginItemSetEnabled 或 Launch Agent | 0.5天 |
| 6 | **菜单栏图标** | 当前 LSUIElement 隐藏了 Dock 图标，但菜单栏无入口。可添加 NSStatusItem 作为常驻入口 | 1天 |
| 7 | **单实例保护** | 当前靠 AppDelegate 管理，需确保第二个实例启动时激活已有窗口 | 0.5天 |

### P2 - 低优先级

| # | 项目 | 说明 | 工作量 |
|---|------|------|--------|
| 8 | **面板动画** | 展开/收起无过渡动画，可添加弹簧动画提升体验 | 0.5天 |
| 9 | **设置面板** | 无可视化设置，用户无法调整刷新频率、热区位置等 | 1天 |
| 10 | **国际化** | 当前中文硬编码，如需国际化需抽离字符串 | 0.5天 |
| 11 | **日志系统** | 当前 print 日志，建议接入 os_log 或 SwiftyBeaver | 0.5天 |

---

## 技术债务

- `ComateStore.swift` 单文件 600+ 行，可拆分为 Store/API/Cache 模块
- `NotchRootView.swift` 视图逻辑与业务逻辑混合，可抽取 ViewModel
- 无单元测试覆盖，建议补充核心逻辑测试

---

## 文件清单

| 路径 | 说明 |
|------|------|
| `ComateNotch/build/ComateNotch.app` | 构建产物（universal binary） |
| `ComateNotch/dist/ComateNotch-1.1.0.dmg` | 分发包 |
| `ComateNotch/Resources/AppIcon.icns` | 应用图标 |
| `ComateNotch/build.sh` | 构建脚本（支持双架构 + 签名） |
