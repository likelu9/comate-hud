# 架构 — Comate HUD

两个独立产物共用一个仓库：macOS 客户端（`ComateNotch/`）与静态官网（`ComateHUD/`）。

## 客户端（ComateNotch/）

```
ComateNotch/
├── build.sh                 # swiftc 双架构编译 → lipo 合并 → ad-hoc 签名 → 组装 .app → hdiutil 出 DMG
├── release.sh               # 构建 + 复制 DMG + 更新 versions.json + 部署官网
├── Info.plist               # 版本号唯一来源（CFBundleShortVersionString / CFBundleVersion）
└── Sources/
    ├── ComateHUDApp.swift      # @main 入口
    ├── AppDelegate.swift       # 生命周期、菜单宿主、退出时 flushSync 兜底上报
    ├── ComateStore.swift       # 状态中枢：轮询、额度、未读、会话、keychain sid、埋点触发
    ├── UsageAPI.swift          # 额度 / 未读 / 云端任务接口
    ├── SessionJournal.swift    # Comate 会话日志增量读取
    ├── NotchPanel.swift        # 刘海窗口（NSPanel 定位到内建屏刘海）
    ├── NotchRootView.swift     # 刘海 HUD 视图
    ├── FloatingPanel.swift     # 任意悬浮模式（悬浮球 + 可拖拽面板）
    ├── HUDShared.swift         # 两种模式共用的菜单定义与度量常量
    ├── UserIdentity.swift      # 经 BaaS auth 接口取 uid/nickname（按 sid 缓存）
    └── ActivityReporter.swift  # 每日活跃上报（日桶 / 去重 / pending 补报）
```

### 数据流
1. `ComateStore` 定时轮询：本机 SQLite（任务）+ HTTP（额度、未读、云端任务）
2. keychain 取 `credential_wps_sid` 需 fork `security`，只在后台队列；供上述 HTTP 与活跃上报共用
3. `ActivityReporter` 在启动 / 跨天 / 退出时上报「当天累计值」到 BaaS 表 `app_activity`（幂等 SET，重试不叠加）
4. 刘海模式与悬浮模式共用同一份菜单与上报逻辑，仅窗口实现不同

## 官网（ComateHUD/）

- `index.html` — 单文件站点（内联 CSS/JS），无框架、无构建、无 CDN
- `vendor/appbase.js` — App Studio BaaS SDK（`createClient({ projectId })`）
- `versions.json` — 版本清单唯一来源，驱动下载按钮、更新日志与版本卡片
- `db/migrations/NNN_*.json` — 表结构：001 许愿 / 002 下载计数 / 003 活跃统计 / 004 活跃表对全体登录用户开放（含 `user` 角色字段白名单）/ 005 把 owner 从 `user` 角色摘出
- `docs/designs/` — DESIGN.md 与参考图

### 数据流
官网 → BaaS（请求头 `X-Project-Id: 3171466180955374`）→ 表 `wish_feedback` / `download_counter` / `app_activity`。

活跃统计面板只对 owner 显示：读 `window.__APP_STUDIO_WM__.uid`，非 owner 连请求都不发（fail-closed）。

## 权限与隔离
- 官网 BaaS 属项目 `3171466180955374`；workspace 根项目是 `3599569812562023`，两者不可混用
- `app_activity`：`default_role: user`（任意已登录 WPS 用户，不限项目成员），`member` = 项目成员。两个角色都 create / read / update allow，delete 一律 deny（含 owner，刻意为之）
- `user` 角色带字段白名单（`visible_fields`）：只放行聚合所需字段，藏 `user_name` / `device_id`。`member` 无 FLS，owner 看全量
- ⚠️ 平台的 FLS 是「受限优先」：owner 只要还持有 `user` 角色就会被一起限掉，所以 005 必须把 owner 从 `user` 摘出（`remove_role`）
