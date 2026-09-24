# Comate HUD
> macOS 刘海/悬浮 HUD：把 WPS Comate 的任务状态、额度、未读消息常驻屏幕顶部；配套一个静态产品官网与下载页。

## 仓库布局
- `ComateNotch/` — macOS 客户端（Swift + AppKit/SwiftUI，无 SPM 依赖，手写 build.sh）
- `ComateHUD/` — 静态官网（原生 HTML/CSS/JS + versions.json + db/migrations），部署为 App Studio 项目 `3171466180955374`

## Commands
- 构建客户端: `cd ComateNotch && ./build.sh` → `build/ComateHUD.app` + `dist/ComateHUD-<ver>.dmg`
- 发版: `cd ComateNotch && ./release.sh <version> <build>`（构建 + 复制 DMG + 更新 versions.json + 部署官网）
- 官网本地预览: `cd ComateHUD && python3 -m http.server 8766`
- 官网发布: `bash <comate-cli skill>/scripts/comate.sh code publish --workspace ComateHUD --version <站内版本> --json`

## Validation
- `cd ComateNotch && ./build.sh` 必须 exit 0，且 `lipo -info` 同时含 arm64 与 x86_64
- 改官网后本地 8766 打开，控制台无 JS 报错（BaaS 接口本地 404 属预期）
- 改上报/统计链路时，用 `defaults read com.wpscomate.hud | grep activity` 检查日桶与 pending
- 改动过的文件都要重读确认

## Structure
See [ARCHITECTURE.md](ARCHITECTURE.md) · 官网视觉 See [ComateHUD/docs/designs/DESIGN.md](ComateHUD/docs/designs/DESIGN.md)

## Conventions
- 客户端新增 Swift 文件必须加进 `ComateNotch/build.sh` 的 `SOURCES` 数组，否则不会被编译
- 版本号只改 `ComateNotch/Info.plist`（`CFBundleShortVersionString` / `CFBundleVersion`）
- 官网不用 CDN/外链资源；建表写在 `ComateHUD/db/migrations/NNN_*.json`
- BaaS 请求必须带 `X-Project-Id: 3171466180955374`（官网项目 ≠ 根项目 `3599569812562023`）
- keychain 读取要 fork `security`，只能在后台队列调用

## Prohibitions
- 不要把 `.publish/` 或任何 `.zip` 写进 `comate.json` 的 zip 源目录
- 不要在官网写死 DMG 体积/版本号（一律由 `versions.json` 驱动）
- 不要放宽 `003_create_app_activity.json` 的 `delete: deny`（owner 也删不掉，刻意为之）
