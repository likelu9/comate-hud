---
version: "1.0"
style: "minimal-dark-macos"
target: "ComateHUD/index.html 新增 #appstats 区块（插在 #versions 与 #wishwall 之间）"
palette:
  primary: "#00d4aa"      # var(--accent)
  background: "#0a0a0f"   # var(--bg)
  surface: "#111118"      # var(--bg-card)
  surfaceHover: "#16161f" # var(--bg-card-hover)
  text: "#f5f5f7"         # var(--text)
  textSecondary: "#8e8e93"
  textDim: "#55555d"
  hairline: "rgba(255,255,255,0.06)"
fonts:
  heading: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'PingFang SC'"
  body: "同上（继承 body，勿另设字体）"
sections:
  - id: "appstats"
    title: "应用统计"
---

# 应用统计区块 · 设计规范

## 0. Design Contract

**风格**：最克制。无运营大屏感、无发光强调、无彩色状态灯。数字靠字重与留白说话，绿色只作点睛。
**硬约束**：零外部资源（无 CDN/字体/图标/图表库/图片）；禁用 `oklch()` / `color-mix()` / `@layer`；颜色只用 hex / `rgb()` / `rgba()` / `hsl()`；SVG 纯手写内联。
**owner-only**：整块与导航入口默认 `hidden`，非 owner / 未登录时零痕迹（不占位、不可 Tab 到、不注册动效）。

### 复用既有 token（取自 index.html `:root`，禁止新增近似色）
`--bg` `--bg-card` `--bg-card-hover` `--text` `--text-secondary` `--text-dim` `--accent` `--accent-glow` `--green` `--radius`(20px) `--max-w`(1080px)

### 复用既有类名 / 写法
- `.container`（宽度与左右 24px padding）
- `<section class="appstats-section">`：`padding: 80px 0`，与 `.version-section` / `.wish-section` 一致
- 区块标题块：`.section-label` + `h2` 用既有 inline 写法 `font-size:clamp(28px,4vw,40px);font-weight:800;letter-spacing:-0.03em;`，副标题 `color:var(--text-secondary)` 15px / `max-width:520px`
- 卡面：`.feature-card` 同款 —— `background: var(--bg-card)` + `border: 1px solid rgba(255,255,255,0.06)` + `border-radius: var(--radius)`；小块用 16px 圆角
- 表格：直接复用 `.compat-table`（含 `th` 大写小字、`td` 底部 hairline、末行去边框），仅追加一个 `.stats-table` 修饰类
- 空态：复用 `.wish-empty`（居中、13px、`var(--text-dim)`）
- 小按钮：复用 `.wish-ops button` 的描边小按钮观感
- 数字对齐：`font-variant-numeric: tabular-nums`（同 `#pv-display` 写法）

## 1. 布局结构（自上而下，单列，间距 40px / 24px）

1. **KPI 四联**：今日活跃 / 近 7 日 / 近 30 日 / 累计活跃用户（按 `uid` 去重）。`display:grid; grid-template-columns:repeat(4,1fr); gap:16px`。
   卡内：标签 12px `var(--text-dim)`、`letter-spacing:.08em`、`text-transform:uppercase`（同 `.compat-table th`）→ 数值 32px/700/`letter-spacing:-0.03em`/`var(--text)` → 底部一行 11px `var(--text-dim)` 说明。仅"今日活跃"卡左上角加 3px×14px 圆角 `var(--accent)` 竖条，其余不加色。
2. **近 30 日每日活跃趋势**（内联 SVG 自绘）：
   `<svg viewBox="0 0 720 180" preserveAspectRatio="none" style="width:100%;height:180px;display:block">`
   - 基线网格：4 条 `rgba(255,255,255,0.04)` 横线（y=0/60/120/180）
   - 面积：`fill="url(#ag)"`，`<linearGradient id="ag">` 由 `rgba(0,212,170,0.18)` → `rgba(0,212,170,0)`（纵向）
   - 折线：`fill="none" stroke="var(--accent)" stroke-width="1.5" vector-effect="non-scaling-stroke" stroke-linejoin="round"`
   - 点位：仅最大值一天画一个 `r=3` `var(--accent)` 圆点
   - 坐标：`x = i * 720/(n-1)`；`y = 180 - (v/max)*150 - 15`（`max` 取序列最大值，最小 1 防除零）
   - 轴标：10px `var(--text-dim)`，只显示首 / 中 / 末三个日期（`MM-DD`）
3. **版本分布横条**：每版本一行 —— 左 13px `var(--text-secondary)` 版本名（`flex:0 0 88px`）→ 轨道 `height:6px;border-radius:999px;background:rgba(255,255,255,0.06)` → 填充 `background:var(--accent);border-radius:999px;width:<pct>%`（单色，不渐变）→ 右 12px `var(--text-dim)` `tabular-nums` 计数。行距 14px，按计数降序，最多 6 行，其余归入"其他"。
4. **今日活跃明细表**：`.compat-table .stats-table`，数据源为 `active_day == 今日` 的行。列：用户 / 版本 / 启动 / 悬停 / 点击 / 设备 / 系统；`user_name` 空则显示 `uid` 前 8 位；数值列右对齐 + `tabular-nums`。

## 2. 各状态表现

| 状态 | 表现 |
| --- | --- |
| 未登录 / 非 owner | `<section id="appstats" hidden>` + `<a id="nav-appstats" hidden>` 写在 HTML 里（默认隐藏，避免闪烁与动效注册）；`isOwner()` 为 false 时**不做任何 DOM 操作**，不请求数据 |
| 加载中 | 4 个 KPI 骨架块（同卡面尺寸，内部 3 条 `rgba(255,255,255,0.06)` 占位条）+ `animation: boot-pulse 1.4s ease-in-out infinite`（复用既有 keyframes）；趋势区只渲染基线网格；高度与真实态一致，禁止布局跳动 |
| 加载失败 | 区内单行 13px `var(--text-dim)` 文案（错误文本按 `errText()` 压成 ≤60 字）+ 一个 `.wish-ops button` 风格「重试」；不弹窗、不 toast、不阻塞滚动 |
| 无数据 | 复用 `.wish-empty` 居中空态文案；趋势区保留基线网格但不画折线与点位；KPI 显示 `0` 而非 `–`；表格用 `.wish-empty` 替换 |

## 3. 移动端（768px）

并入既有 `@media (max-width:768px)` 块（紧跟 `.version-item .vi-head` 之后，不新开断点）：
- `.appstats-kpi`：`grid-template-columns:repeat(2,1fr); gap:12px`；数值降为 26px，卡 padding 20px 16px
- 趋势 SVG 高度 180px → 140px；轴标仅保留首 / 末两个日期
- 版本横条：版本名 `flex-basis:64px`；超过 4 行折叠为前 4 + "其他"
- 明细表：外层 `.stats-scroll{overflow-x:auto}`，隐藏「设备」「系统」两列（`.stats-table .col-opt{display:none}`）

## 4. 与 `.reveal` 动效衔接

- **不**给整块加 `.reveal`（整块位移会让 KPI 与图表一起漂移，显重）；改为给 4 个子块各加 `.reveal`，即 4 段依次淡入。
- 复用页面既有 observer 参数：`threshold:0.1`、`rootMargin:'0px 0px -40px 0px'`、`classList.add('visible')`。
- **关键顺序**：owner 校验通过 → `removeAttribute('hidden')` → 再执行 `document.querySelectorAll('.reveal:not(.visible)')` 重新 observe（同 index.html 既有二次扫描写法）。否则隐藏期间被观察的元素永远拿不到 `visible`。
- 尊重 `prefers-reduced-motion`：该媒体查询已在页内，无需新增。

## 5. Acceptance Contract

- [ ] 区块位于 `#versions` 与 `#wishwall` 之间；导航入口位于「更新日志」之后、`#download` 之前
- [ ] 非 owner / 未登录：区块与导航入口均不可见、不占位、不发请求；页面其余部分零变化
- [ ] 无任何外部请求（Network 面板除既有 SDK/图片外无新增）；无图表库、无 canvas、无 base64 图
- [ ] 源码中不出现 `oklch(` / `color-mix(` / `@layer`
- [ ] 颜色全部来自既有 `:root` 变量或 `rgba(255,255,255,0.0x)` / `rgba(0,212,170,0.x)`
- [ ] 趋势图 `viewBox` 固定、`preserveAspectRatio="none"` 下描边不虚（`vector-effect="non-scaling-stroke"`）
- [ ] 加载中 / 失败 / 空 三态可复现，且加载中不引起布局跳动
- [ ] 375px 与 768px 宽度下无横向滚动条；明细表仅自身横向滚动
- [ ] 4 个子块依次 `.reveal` 淡入，不出现"隐藏后永不显示"
- [ ] 未修改 `index.html` 既有 token、类名语义与任何既有区块
