# Comate HUD
> macOS 刘海/悬浮 HUD：把 WPS Comate 的任务状态、额度、未读消息常驻屏幕顶部；配套一个静态产品官网与下载页。

## 仓库布局
- `ComateNotch/` — macOS 客户端（Swift + AppKit/SwiftUI，无 SPM 依赖，手写 build.sh）
- `ComateHUD/` — 静态官网（原生 HTML/CSS/JS + versions.json + db/migrations），部署为 App Studio 项目 `3171466180955374`

## Commands
- 构建客户端: `cd ComateNotch && ./build.sh` → `build/ComateHUD.app` + `dist/ComateHUD-<ver>.dmg`
- 发版: `cd ComateNotch && ./release.sh <version> <build>`（构建 + 复制 DMG + **实测 DMG 体积写入 versions.json** + 部署官网）
  - 体积唯一来源 = release.sh Step 2.5 的 `stat` 实测值（≥1MiB 显示 `X.Y MB`）；重跑同一版本号只回填 size，不新增条目
- 官网本地预览: `cd ComateHUD && python3 -m http.server 8766`
- 官网发布: `bash <comate-cli skill>/scripts/comate.sh code publish --workspace ComateHUD --version <站内版本> --json`

## Validation
- `cd ComateNotch && ./build.sh` 必须 exit 0，且 `lipo -info` 同时含 arm64 与 x86_64
- 改官网后本地起 http.server 打开，控制台无 JS 报错（BaaS 接口本地 **401** 属预期：全表要求登录）
- 改上报/统计链路时，用 `defaults read com.wpscomate.hud | grep activity` 检查日桶与 pending
- 改动过的文件都要重读确认

## Structure
See [ARCHITECTURE.md](ARCHITECTURE.md) · 官网视觉 See [ComateHUD/docs/designs/DESIGN.md](ComateHUD/docs/designs/DESIGN.md)

## Conventions
- 客户端新增 Swift 文件必须加进 `ComateNotch/build.sh` 的 `SOURCES` 数组，否则不会被编译
- 版本号只改 `ComateNotch/Info.plist`（`CFBundleShortVersionString` / `CFBundleVersion`）
- 官网不用 CDN/外链资源；建表写在 `ComateHUD/db/migrations/NNN_*.json`
- BaaS 请求必须带 `X-Project-Id: 3171466180955374`（官网项目 ≠ 根项目 `3599569812562023`）
- BaaS 表**全表要求登录**（无 Cookie 一律 `401 未登录或登录已过期`）：客户端上报依赖 keychain 的 `wps_sid`，读不到就没有任何上报通道，只能跳过
- 建表时的 access-pattern 默认 `default_role: member` = 只有**项目成员**能读写；要让任意登录用户能读写，用 `define_table_roles` 把 `default_role` 改成 `user`（`access` 字段只在建表时生效）
- `define_table_roles` **只能走 Migrate API**（`db.py migrate --json '<migration>' --confirm`）：auth API 的 action 列表里没有它，直接 POST `db/auth` 会报 `unknown auth action`。反过来 Migrate API 不支持 `create-table` 之外的逐操作权限展开
- 三张表的开放范围：`app_activity` user=create/read/update + FLS 白名单；`wish_feedback` user=create/read（回复/删除限 member）；`download_counter` user=create/read/update（delete 限 member）。三张表 default_role 均为 `user`
- 只读核对权限用 RBAC 查询接口（`POST /api/manage/v1/db/auth`）：`get_table_access` / `get_user_roles` / `check`。注意 `check` 不模拟 `default_role`，对无显式角色的 uid 恒返回 false，不能用来验证非成员；`get_user_roles` 有滞后（会返回上一次变更前的状态）
- `set_field_permission` 的 `fields` 必须是**逗号分隔字符串**；传数组会被静默存成 `[""]`，等于把该角色所有字段都藏掉
- `define_table_roles` 会把 `default_role` materialize 到**已有用户**身上（owner 也会被挂上），而平台的 FLS 是「受限优先」→ 只要该角色在**任意表**上设了 `visible_fields`，owner 就会被限。materialize 是**项目级**的：改任何一张表的 `default_role=user` 都会把 owner 挂上 `user`，从而触发 `app_activity` 的字段白名单（owner 的 `user_name` / `device_id` 被藏）
- 因此**每次**执行 `define_table_roles` 之后都要跟一次 `remove_role` 把 owner 从 `user` 摘出（见 migration 005、007），并用带凭据的 BaaS 查询实测 `device_id` 是否读得回来（`get_user_roles` 有滞后，不能作为判据）
- 活跃上报取不到用户身份时退化为**设备维度 uid**（`anon-<设备指纹前 20 位>`，昵称留空），不再整条跳过；401/403 退避 6 小时再试
- 官网「应用统计」：KPI / 趋势 / 版本分布对访客公开，**今日明细（含用户名 + 设备标识）仅 owner**；owner 判定优先认 `window.__APP_STUDIO_WM__.uid`，`localStorage` 名字白名单只是本地开发回退
- keychain 读取要 fork `security`，只能在后台队列调用

## Prohibitions
- 不要把 `.publish/` 或任何 `.zip` 写进 `comate.json` 的 zip 源目录
- 不要在官网写死 DMG 体积/版本号（一律由 `versions.json` 驱动）
- 不要放宽 `003_create_app_activity.json` 的 `delete: deny`（owner 也删不掉，刻意为之）
