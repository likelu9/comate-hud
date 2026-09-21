# ComateNotch 分发打包（DMG）+ 阻塞项修复

## 项目概述
macOS 刘海悬浮 HUD（SwiftUI + AppKit，swiftc 直编，非 Xcode 工程），显示 Comate 任务状态灯与模型额度。当前仅本机自用，本次目标：修掉阻止他人安装使用的阻塞项与必要 bug，产出 DMG 供团队其他 Mac 用户安装。

## 审查结论

### 本次修（阻塞项）
| # | 问题 | 后果 | 修法 |
|---|------|------|------|
| 1 | Info.plist 缺 `NSAppleEventsUsageDescription` | 消息中心用 AppleScript 定位铃铛，别人机器上被系统拒 | 补 key |
| 2 | 只编 arm64 | Intel Mac 直接打不开 | 双架构编译 + lipo |
| 3 | `NSScreen.main!` 强解包（NotchPanel.swift:52） | 无显示器 / 切用户场景崩溃 | 兜底 `NSScreen.screens.first` |
| 4 | `fetchWpsSid()` 在主线程 fork `/usr/bin/security` | 别人首次启动弹 keychain 授权框时**面板卡死**；且每次拉取都 fork（30s 内 3 次） | 移到后台队列 + sid 缓存（401 时失效重读） |
| 5 | 云端任务合并丢 `credits30d`（ComateStore.swift:667） | 每 30s 行上智点标记闪没 | 合并时回填，与 refresh() 一致 |
| 6 | 黄灯文案「思考中」 | 用户要求 | →「工作中」（ComateStore.swift:164 + 画布说明） |
| 7 | 无应用图标 | Finder 空白图标 | designer 出 3 版 → .icns |
| 8 | 无签名 | 下载后 Gatekeeper 拦截 | ad-hoc 签名 + 首次打开说明 |

### 留待优化清单（本轮不动，写进计划存档）
菜单栏图标/退出入口、开机自启、多屏与分辨率变化跟随、单实例互斥、`journals` 缓存无上限、`noCredential` 不排重试（后装 Comate 最多等 10 分钟）、`openSession` 用 print 未落系统日志、App Nap 定时器节流、`openMessageCenter` 硬编码进程名「WPS Comate」。

## 技术选型
| 决策 | 备选 | 选择 | 理由 |
|---|---|---|---|
| 分发形态 | DMG / ZIP / PKG | **DMG** | 拖入 Applications 最直观 |
| 签名 | Developer ID / ad-hoc / 不签 | **ad-hoc** | 本机 0 个签名身份，公证不可行 |
| 架构 | arm64 / universal | **universal** | Intel Mac 也能装，体积代价可忽略 |
| 图标 | 3 个概念 | **logo+红绿灯三版** | 用户选定后再落地 |

## 关键设计
- **构建**：`build.sh` 改为两遍编译（arm64 / x86_64）→ `lipo -create` → 组装 bundle → `codesign --force --deep -s -` → 版本号从 Info.plist 读。
- **sid 缓存**：新增 `private var cachedSid: String?`，首次在后台队列读；401 时清空缓存触发重读。读 keychain 仍用 `security` CLI（与 Comate 写入方式一致），但**绝不阻塞主线程**。
- **图标链路**：designer 出 SVG/PNG → 生成 1024 基准 `AppIcon.icns`（`iconutil`）→ Info.plist 加 `CFBundleIconFile`。
- **产物**：`dist/ComateNotch-<版本>.dmg`（app + Applications 软链）+ `dist/安装说明.txt`。

## 实施步骤

### Phase 1 阻塞项修复 (P0)
1. Info.plist：补 `NSAppleEventsUsageDescription`、`CFBundleIconFile`、版本号
2. NotchPanel：`NSScreen.main` 兜底
3. 黄灯文案「思考中」→「工作中」（含画布说明同步）
**交付物**：可编译的新源码  **acceptance**：build.sh 通过，文案生效

### Phase 2 必要 bug 修复 (P0)
1. `fetchWpsSid` 移出主线程 + sid 缓存 + 401 失效重读
2. 云端合并回填 `credits30d`
**交付物**：同上  **acceptance**：面板不再卡顿；智点标记不再闪

### Phase 3 应用图标 (P0)
1. 委派 designer 出 3 版图标（logo+红绿灯三概念）
2. 用户选定 → 转 .icns 落地
**交付物**：`Resources/AppIcon.icns`  **acceptance**：Dock/Finder 显示正常

### Phase 4 打包分发 (P0)
1. build.sh 改双架构 + 签名
2. 制作 DMG + 安装说明
**交付物**：`dist/ComateNotch-<版本>.dmg`  **acceptance**：`lipo -info` 双架构、`codesign -v` 通过、挂载可拖拽

### Phase 5 验证 (P0)
1. 模拟他人首次安装：去隔离属性 → 启动 → 面板正常、任务/额度可读
2. Intel 架构产物校验
3. 回归：展开/收起、页脚切换、状态灯
**acceptance**：全部通过；失败项如实报告

## 风险与注意事项
- **无证书 → 无法公证**：别人下载后必须手动放行（右键打开或去隔离属性），必须在安装说明里写清，否则会被当成「装不上」。
- **keychain 首次授权**：别人首次启动会弹一次「security 想访问密钥串」，选「始终允许」后不再打扰；若选「拒绝」则用量区显示「—」（不影响任务列表）。
- **TCC 权限与重签名**：ad-hoc 签名下，每次重新构建二进制签名都会变，已授的自动化/辅助功能权限会失效需重授；同一 DMG 内分发则不受影响。
- **AppleScript 硬编码**：`openMessageCenter` 依赖进程名「WPS Comate」，改名或本地化后会失效（已列入待优化）。

## 验证方式
```bash
cd ComateNotch && ./build.sh          # 构建
lipo -info build/ComateNotch.app/Contents/MacOS/ComateNotch   # 期望 arm64 + x86_64
codesign -dv build/ComateNotch.app    # 期望 Signature=adhoc
hdiutil verify dist/ComateNotch-*.dmg
xattr -dr com.apple.quarantine /Applications/ComateNotch.app && open -a ComateNotch
```

## 关键文件清单
| 文件 | 说明 |
|---|---|
| ComateNotch/Info.plist | 权限说明键、图标、版本 |
| ComateNotch/build.sh | 双架构 + 签名 + 版本注入 |
| ComateNotch/Sources/ComateStore.swift | keychain 读取/缓存、credits30d 回填、状态文案 |
| ComateNotch/Sources/NotchPanel.swift | NSScreen 兜底 |
| ComateNotch/Resources/AppIcon.icns | 新增应用图标 |
| dist/ComateNotch-<版本>.dmg | 分发产物 |
| dist/安装说明.txt | 首次打开步骤 |
