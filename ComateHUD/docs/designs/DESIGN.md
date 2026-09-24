---
version: "1.5"
style: "minimal-dark-macos"
target: "ComateHUD/index.html：① #appstats 区块（插在 #versions 与 #wishwall 之间）；② hero 内下载区 #download 重构（公共信息行 / MAC·WIN·GitHub 三按钮 / 按钮外体积元信息行 / macOS 安装说明 hover 气泡）；③ 全站文案精简（13 → 12 区块：删除 #how「使用流程」，其去重后并入 #features；#compat 表格降级为一行标签带）+ 全站排版节奏重排（区块 padding / 网格 gap / 卡片内边距 / 正文行高字号）；④ 1.5 区块重排与信息精简（见 §10）；⑤ 应用统计改版（见 §10.7）：与「能力提供」换位、文案口语化、新增人数句与一键分享：hero 版本记录改锚点行 #release-line、「技术栈」→「如何实现」并补三方应用背景、#compat 并入 #tech 且删除该区块与导航项、#versions 移到 #wishwall 正上方（导航同步）、更新日志条目收起态行高压缩 + 日期加重、versions.json 文案精简（41 → 30 条）"
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
  - id: "download"
    title: "下载区（公共信息行 · MAC/WIN 按钮 · 体积元信息 · 安装说明气泡）"
  - id: "copy-spacing"
    title: "全站文案精简清单 + 排版节奏规范（12 区块 · 删除 #how · #compat 降级为标签带）"
  - id: "revision-1.5"
    title: "1.5 修订：区块重排与信息精简（锚点行版本记录 · 如何实现 · #compat 并入 #tech · #versions 移到 #wishwall 前）"
  - id: "appstats-share"
    title: "应用统计改版：与能力提供换位 · 文案口语化 · 人数句 · 一键分享（§10.7）"
references:
  - "references/stats-mockup.svg"
  - "references/download-section.svg"
  - "references/copy-rhythm.svg"
release_contract:
  size_source: "versions.json → versions[0].size"
  writer: "ComateNotch/release.sh（发版时用 stat 计算 DMG 字节数并格式化写入）"
  fallback: "size 为 \"-\" / 空 → 官网整条隐藏体积，绝不回落硬编码"
---

# 应用统计区块 · 设计规范

## 0. Design Contract

**风格**：最克制。无运营大屏感、无发光强调、无彩色状态灯。数字靠字重与留白说话，绿色只作点睛。
**硬约束**：零外部资源（无 CDN/字体/图标/图表库/图片）；禁用 `oklch()` / `color-mix()` / `@layer`；颜色只用 hex / `rgb()` / `rgba()` / `hsl()`；SVG 纯手写内联。
**可见性（2026-09-24 调整）**：区块与导航入口**对所有人公开**（HTML 里不再带 `hidden`）；KPI / 趋势 / 版本分布属聚合指标，人人可见；**今日活跃明细含用户名与设备标识，仅 owner 可见**（`#appstats-today-block` 默认 `hidden`，owner 才解隐）。
**登录前提**：BaaS 全表要求登录（实测无 Cookie 直接 401），未登录访客请求必然失败 → 不渲染数据，只给一行「登录 WPS 账号后刷新页面即可查看应用统计」。
**owner 判定**：`platformUid() === '1388246874'`（平台注入的 `window.__APP_STUDIO_WM__.uid`）优先，`localStorage` 名字白名单仅作本地开发回退 —— 只认名字会漏判线上 owner。

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
4. **今日活跃明细表（仅 owner）**：`.compat-table .stats-table`，数据源为 `active_day == 今日` 的行。列：用户 / 版本 / 启动 / 悬停 / 点击 / 设备 / 系统；`user_name` 空则显示 `uid` 前 8 位；数值列右对齐 + `tabular-nums`。

## 2. 各状态表现

| 状态 | 表现 |
| --- | --- |
| 访客（已登录，非 owner） | 区块与导航入口可见；渲染 KPI / 趋势 / 版本分布；`#appstats-today-block` 保持 `hidden` |
| 未登录访客（接口 401） | 区块仍在（标题 + 副标题 + 一行提示），KPI / 趋势 / 版本分布 / 明细**整块收起**，提示「登录 WPS 账号后刷新页面即可查看应用统计」，不给重试按钮 |
| 加载中 | 4 个 KPI 骨架块（同卡面尺寸，内部 3 条 `rgba(255,255,255,0.06)` 占位条）+ `animation: boot-pulse 1.4s ease-in-out infinite`（复用既有 keyframes）；趋势区只渲染基线网格；高度与真实态一致，禁止布局跳动 |
| 加载失败（已登录） | 内容位**整块收起**（`statsShowBlocks(false)`）+ 区内单行 13px `var(--text-dim)` 文案 + 一个 `.wish-ops button` 风格「重试」；不弹窗、不 toast、不阻塞滚动 |
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
- **关键顺序**：`removeAttribute('hidden')`（区块与导航）→ `revealScan()` 重新 observe `.reveal:not(.visible)`。区块现已默认可见，`revealScan()` 主要服务于「失败后重试成功」这条恢复路径。
- **收起 KPI 用内联 `style.display`**，不能用 `hidden` 属性：`.appstats-kpi` 自带 `display:grid`，作者样式会盖掉 UA 的 `[hidden]{display:none}`。`.appstats-block` 无 display 声明，可以照常用 `hidden`。
- 尊重 `prefers-reduced-motion`：该媒体查询已在页内，无需新增。

## 5. Acceptance Contract

- [ ] 区块位于 `#powered` 与 `#versions` 之间（1.5 修订与「能力提供」换位）；导航入口位于「能力提供」之后、`更新日志` 之前
- [ ] 区块与导航入口在 HTML 里不带 `hidden`（默认可见）
- [ ] 访客（非 owner）：可见 KPI / 趋势 / 版本分布，`#appstats-today-block` 不可见
- [ ] 未登录访客：区块保留标题与一行登录提示，内容位全部收起（不残留骨架）
- [ ] owner：明细块可见，用户名与设备列正常渲染
- [ ] 收起 KPI 用内联 `style.display`（`display:grid` 会盖掉 UA 的 `[hidden]{display:none}`）
- [ ] 无任何外部请求（Network 面板除既有 SDK/图片外无新增）；无图表库、无 canvas、无 base64 图
- [ ] 源码中不出现 `oklch(` / `color-mix(` / `@layer`
- [ ] 颜色全部来自既有 `:root` 变量或 `rgba(255,255,255,0.0x)` / `rgba(0,212,170,0.x)`
- [ ] 趋势图 `viewBox` 固定、`preserveAspectRatio="none"` 下描边不虚（`vector-effect="non-scaling-stroke"`）
- [ ] 加载中 / 失败 / 空 三态可复现，且加载中不引起布局跳动
- [ ] 375px 与 768px 宽度下无横向滚动条；明细表仅自身横向滚动
- [ ] 4 个子块依次 `.reveal` 淡入，不出现"隐藏后永不显示"
- [ ] 未修改 `index.html` 既有 token、类名语义与任何既有区块

---

# 下载区块 · 设计规范

> 范围：`ComateHUD/index.html` hero 区块内的下载区（`#download`）。**只重构下载区**，hero 的 badge / h1 / subtitle / hero-lights、以及 mockup / features / appstats 等区块一律不动。
> 视觉稿：`docs/designs/references/download-section.svg`（自包含 SVG，三种状态并排）。

## 0. Design Contract

**风格**：延续 minimal-dark-macos。整块只有一个 accent 填充元素 —— MAC 主按钮；其余靠 hairline、字重与留白分层。不要运营大促感（禁止多个发光按钮、禁止渐变按钮、禁止彩色徽标堆叠）。
**硬约束**：纯静态单文件页，零外部资源（无 CDN / 无外部字体 / 无图标库 / 无图片，图标一律手写内联 SVG）；禁用 `oklch()` / `color-mix()` / `@layer`；颜色只用 hex / `rgb()` / `rgba()` / `hsl()`；移动端规则并入既有 `@media (max-width:768px)` 块，**不新开断点**。

### 复用既有 token（取自 index.html `:root`，禁止新增近似色）
`--bg`(#0a0a0f) `--bg-card`(#111118) `--bg-card-hover` `--text`(#f5f5f7) `--text-secondary`(#8e8e93) `--text-dim`(#55555d) `--accent`(#00d4aa) `--accent-glow`(rgba(0,212,170,0.25)) `--radius`(20px) `--max-w`(1080px)
允许的中性色只有：`rgba(255,255,255,0.03 / 0.06 / 0.08 / 0.1 / 0.16)`、`rgba(0,0,0,0.4)`、`rgba(0,212,170,0.08 / 0.35)`。

### 复用既有类名 / 写法
`.container`（1080px + 左右 24px padding）、`.hero-actions`（按钮行，`flex / center / wrap / gap:12px`）、`.btn-download`（按钮基类，`inline-flex` + `gap:10px` + `border-radius:14px`）、`.btn-primary`、`.btn-secondary`、`.btn-coming`、`.hero-tags`（元信息行基类）、`.release-toggle`（Release Notes 折叠，保留不动）。

### 三条不可协商的原则
1. **数据唯一来源 = `versions.json` 的 `versions[0]`**。应用名是常量；版本号、发布日期、体积**全部由 JS 运行时注入**，HTML 里不得出现任何具体版本号或体积（含 `~1.4 MB` 这类硬编码）。发版脚本负责把 `size` 写进 `versions.json`，官网自动跟随。
2. **体积在按钮之外**，与系统要求合并成一行元信息；按钮文案里不再出现版本与体积。
3. **按钮文案静态化**：MAC 按钮文案固定为「Mac 版」、WIN 为「Win 版」（不再随版本变长而变宽），版本信息上移到公共信息行。

### 主次层级（唯一权威顺序）
| 层级 | 元素 | 处理 |
| --- | --- | --- |
| 1 · 唯一 CTA | MAC 下载按钮 | `.btn-download.btn-primary`：accent 实心 + `0 0 24px var(--accent-glow)` + hover 抬升 |
| 2 · 次要出口 | GitHub 按钮 | `.btn-download.btn-secondary`：`rgba(255,255,255,0.06)` 面 + hairline 描边，无 glow |
| 3 · 不可用 | WIN 按钮 | `.btn-coming`：与 Mac 版同一套实心按钮（同填充形式/圆角/字号/无边框），仅整体降对比度 + 无 glow + 无 hover 反馈；「敬请期待」在按钮正下方小字 |
| 4 · 工具 | 安装说明触发点 | 44×44 ghost 图标按钮，仅在 hover / focus 时染 accent |

## 1. HTML 结构骨架（类名层级）

```html
<section class="hero">
  <div class="container">
    <!-- …badge / h1 / subtitle / hero-lights 原样保留… -->

    <div class="dl-block" id="download">
      <!-- ① 公共信息行：应用名（静态）+ 版本 + 可选日期（均运行时注入） -->
      <div class="dl-head">
        <span class="dl-app">Comate HUD</span>
        <span class="dl-ver" id="dl-version" hidden>v1.0.0</span>
        <span class="dl-date" id="dl-date" hidden></span>
      </div>

      <!-- ② 按钮行：MAC 主 / 安装说明触发点 / WIN 敬请期待 / GitHub -->
      <div class="hero-actions dl-actions">
        <a id="dl-btn" href="#" class="btn-download btn-primary" download>
          <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.37 1.43c0 1.14-.42 2.2-1.25 3.18-.87 1.03-1.9 1.63-2.86 1.55-.13-.98.35-2.06 1.16-3.02.83-.99 2.1-1.65 2.95-1.71zM19.7 17.1c-.5 1.15-.74 1.66-1.38 2.67-.9 1.42-2.16 3.19-3.72 3.2-1.39.01-1.75-.9-3.64-.89-1.89.01-2.29.91-3.68.9-1.56-.01-2.75-1.61-3.64-3.02-2.5-3.94-2.76-8.56-1.22-11.02 1.1-1.75 2.83-2.78 4.46-2.78 1.66 0 2.7.91 4.07.91 1.33 0 2.14-.91 4.06-.91 1.45 0 2.99.79 4.08 2.16-3.59 1.97-3 7.09.61 8.78z"/></svg>
          <span id="dl-text">Mac 版</span>
        </a>

        <span class="dl-help" id="dl-help">
          <button class="dl-help-trigger" id="dl-help-trigger" type="button"
                  aria-expanded="false" aria-controls="dl-help-pop" aria-label="macOS 安装说明" title="macOS 安装说明">
            <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 11v5.2"/><circle cx="12" cy="7.9" r="1.05" fill="currentColor" stroke="none"/></svg>
            <span class="dl-help-label">安装说明</span>
          </button>

          <div class="dl-help-pop" id="dl-help-pop" role="region" aria-label="macOS 安装说明">
            <p class="dl-help-row"><span class="dl-help-k">【安装】</span>把左侧的 Comate HUD.app 拖到 Applications 文件夹即可。</p>
            <p class="dl-help-row"><span class="dl-help-k">【首次打开】</span>本应用未使用 Apple 付费开发者证书签名，macOS 会拦截首次启动（提示「未打开“ComateHUD”」，Apple 无法验证其安全性）。双击后任选一种方式放行：</p>
            <p class="dl-help-sub">方式一：打开「系统设置」→「隐私与安全性」，下滑到「安全性」区域，找到「已阻止“ComateHUD”以保护 Mac」，点「仍要打开」，在二次弹窗「打开“ComateHUD”？」中再点「仍要打开」，输入系统密码即可。</p>
            <p class="dl-help-sub">方式二：打开「终端」，执行下面这行命令：</p>
            <code class="dl-help-code" id="dl-help-cmd" tabindex="0" aria-label="终端命令，可选中复制">xattr -dr com.apple.quarantine /Applications/ComateHUD.app</code>
            <p class="dl-help-sub dl-help-note">然后双击启动</p>
          </div>
        </span>

        <span class="dl-win-wrap">
          <span id="dl-win" class="btn-download btn-coming" aria-disabled="true" aria-describedby="dl-win-note">
            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M2.6 4.9 10.4 3.7v7.6H2.6zM11.6 3.5 21.4 2.1v9.2h-9.8zM2.6 12.7h7.8v7.6L2.6 19.1zM11.6 12.7h9.8v9.2l-9.8-1.4z"/></svg>
            <span>Win 版</span>
          </span>
          <span class="dl-win-note" id="dl-win-note">敬请期待</span>
        </span>

        <a href="https://github.com/likelu9/comate-hud" class="btn-download btn-secondary" target="_blank" rel="noopener">
          <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.4 7.4 0 0 1 2-.27c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
          <span>GitHub</span>
        </a>
      </div>

      <!-- ③ 元信息行：体积（数据驱动）+ 系统要求（静态），全部在按钮之外 -->
      <div class="hero-tags dl-tags">
        <span class="dl-tag" id="dl-size" hidden>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5z"/><path d="M3 7.5l9 4.5 9-4.5M12 12v9"/></svg>
          <span id="dl-size-text">1.8 MB</span> DMG
        </span>
        <span class="dl-tag">
          <svg class="solid" viewBox="0 0 24 24" aria-hidden="true"><path d="M16.37 1.43c0 1.14-.42 2.2-1.25 3.18-.87 1.03-1.9 1.63-2.86 1.55-.13-.98.35-2.06 1.16-3.02.83-.99 2.1-1.65 2.95-1.71zM19.7 17.1c-.5 1.15-.74 1.66-1.38 2.67-.9 1.42-2.16 3.19-3.72 3.2-1.39.01-1.75-.9-3.64-.89-1.89.01-2.29.91-3.68.9-1.56-.01-2.75-1.61-3.64-3.02-2.5-3.94-2.76-8.56-1.22-11.02 1.1-1.75 2.83-2.78 4.46-2.78 1.66 0 2.7.91 4.07.91 1.33 0 2.14-.91 4.06-.91 1.45 0 2.99.79 4.08 2.16-3.59 1.97-3 7.09.61 8.78z"/></svg>
          macOS 12.0+
        </span>
        <span class="dl-tag">
          <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="7" width="10" height="10" rx="2.2"/><path d="M10 7V4.2M14 7V4.2M10 20v-2.8M14 20v-2.8M7 10H4.2M7 14H4.2M20 10h-2.8M20 14h-2.8"/></svg>
          Apple Silicon &amp; Intel
        </span>
      </div>

      <!-- ④ Release Notes 折叠：位置与结构原样保留，仅去掉 inline margin-top 改由 CSS 统一控制 -->
      <details class="release-toggle">…既有内容不动…</details>
    </div>
  </div>
</section>
```

**结构要点**
- `id="download"` 从原来的 `.hero-actions` 上移到 `.dl-block`（导航「下载」与页脚 `#download` 锚点语义不变，改为锚到整块），并给 `.dl-block` 加 `scroll-margin-top: 96px` 抵消固定导航高度。
- `.dl-help` 是**触发器 + 气泡的同一父容器**：这是 hover 时鼠标从图标移入气泡而不中断（气泡可停留选中）的前提，也是 `:focus-within` 生效的前提。
- 三个 `.dl-tag` 的图标全部手写内联 SVG，`apple` 路径直接复用页面既有的 `nav .mb-apple` 路径；`windows` 为四格旗（`fill`）；`chip`/`box` 为 `stroke` 线性图标。**emoji（🍎⚡📦）全部移除**。
- `#dl-size` / `#dl-version` / `#dl-date` 初始带 `hidden`，避免数据到达前闪现占位符。

## 2. 关键 CSS（可执行，追加到 index.html `<style>` 中下载区相关规则处）

### 2.1 公共信息行
```css
.dl-block { scroll-margin-top: 96px; }
.dl-head { display: flex; align-items: center; justify-content: center; gap: 10px; flex-wrap: wrap; margin-bottom: 18px; }
.dl-head .dl-app { font-size: 17px; font-weight: 700; letter-spacing: -0.01em; color: var(--text); }
.dl-head .dl-ver { display: inline-flex; align-items: center; padding: 3px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); color: var(--text); font-variant-numeric: tabular-nums; white-space: nowrap; }
.dl-head .dl-date { font-size: 12px; color: var(--text-dim); font-variant-numeric: tabular-nums; }
.dl-head .dl-date::before { content: '·'; margin-right: 8px; color: var(--text-dim); }
.dl-head .dl-ver[hidden], .dl-head .dl-date[hidden] { display: none; }
```
- 版本胶囊用中性白面，**不染 accent**：accent 只能属于 MAC 主按钮。
- `white-space: nowrap` + `tabular-nums`：`v1.4.0` → `v1.12.3` 变长时胶囊自然变宽，行内 `flex-wrap: wrap` 兜底，不挤压、不换行折断。

### 2.2 按钮行与三种按钮
```css
.dl-actions { position: relative; }            /* 供气泡绝对定位兜底 */
.dl-actions .btn-download { white-space: nowrap; }
.dl-actions .btn-download svg { flex: none; }

/* 次级：GitHub 复用既有 .btn-secondary，不改 */
/* 不可用：WIN —— 与 Mac 版同一套实心按钮（同填充形式/圆角/字号/无边框），仅整体降对比度 */
.btn-coming { background: rgba(0,212,170,0.12); color: rgba(0,212,170,0.6); box-shadow: none; cursor: not-allowed; }
.btn-coming svg { opacity: 0.6; }
/* 「敬请期待」移到按钮正下方：绝对定位，不参与按钮行几何（Mac/Win 保持同一基线） */
.dl-win-wrap { position: relative; display: inline-flex; }
.dl-win-note { position: absolute; top: calc(100% + 6px); left: 0; right: 0; text-align: center; font-size: 12px; line-height: 1.2; color: var(--text-dim); white-space: nowrap; }
```
- WIN 的不可用观感由**四个信号**叠加：① 虚线 hairline 边框（不是实心面）；② 无 glow、无抬升、无 hover 响应；③ 图标与文字降为 `--text-secondary` / `--text-dim`；④ 独立的「敬请期待」胶囊标签。**不使用 `opacity: 0.5`**（会让描边与文字一起糊掉，且没有语义）。
- 因为改成 `<span>` 而非 `<a href="javascript:void(0)">`，`cursor: not-allowed` 能真实生效，同时它天然不可点、不进 Tab 序列。
- 按钮行宽度预算：MAC(≈196) + gap12 + 触发点(44) + gap12 + WIN(≈224–243，取决于「敬请期待」胶囊实测宽度) + gap12 + GitHub(≈148) ≈ **645–667px**，且**不随版本号变长而变宽**（版本已移出按钮）。
  769px 视口下 `.container` 内容宽 = 769 − 48 = **721px** > 667px → 769px 以上绝不换行；≤768px 交给移动端规则（允许换行）。
  视觉稿 `references/download-section.svg` 按窄值 626–645px 绘制，规范预算按上界 667px 校验。

### 2.3 元信息行（体积 + 系统要求，按钮之外）
```css
.dl-tags { margin-top: 16px; gap: 16px; }
.dl-tag { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-dim); }
.dl-tag svg { width: 14px; height: 14px; flex: none; fill: none; stroke: currentColor; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round; opacity: 0.9; }
.dl-tag svg.solid { fill: currentColor; stroke: none; }
.dl-tag[hidden] { display: none; }             /* 必须写：inline-flex 会盖掉 [hidden] 的 UA display:none */
```
- 顺序固定为 **体积 → 系统要求 → 架构**（体积是唯一每次发版都会变的那一项，放最前）。
- `1.8 MB` 由 `#dl-size-text` 注入，`DMG` 是静态后缀；`1.8 MB` 与 `12.4 MB` 等两位数体积都在同一行内自然容纳。

### 2.4 安装说明：触发点 + hover 气泡
```css
.dl-help { position: relative; display: inline-flex; align-items: center; }
.dl-help-trigger { display: inline-flex; align-items: center; justify-content: center; gap: 6px; width: 44px; height: 44px; padding: 0; border-radius: 12px; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); color: var(--text-secondary); font: inherit; font-size: 13px; font-weight: 600; cursor: pointer; transition: background 0.2s, color 0.2s, border-color 0.2s; }
.dl-help-trigger svg { width: 20px; height: 20px; flex: none; fill: none; stroke: currentColor; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
.dl-help-trigger:hover, .dl-help.is-open .dl-help-trigger { background: rgba(0,212,170,0.08); border-color: rgba(0,212,170,0.35); color: var(--accent); }
.dl-help-trigger:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.dl-help-label { display: none; }              /* 桌面仅图标，移动端才显示文字 */

.dl-help-pop { position: absolute; bottom: calc(100% + 14px); left: 50%; transform: translate(-50%, 6px); width: min(440px, calc(100vw - 48px)); max-height: calc(100vh - 40px); overflow-y: auto; padding: 18px 20px 20px; background: var(--bg-card); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; box-shadow: 0 18px 48px rgba(0,0,0,0.6); text-align: left; font-size: 13px; line-height: 1.75; color: var(--text-secondary); opacity: 0; visibility: hidden; pointer-events: none; z-index: 40; user-select: text; -webkit-user-select: text; transition: opacity 0.18s ease, transform 0.18s cubic-bezier(0.22,1,0.36,1), visibility 0s linear 0.18s; }
.dl-help-pop::before { content: ''; position: absolute; bottom: -5px; left: 50%; margin-left: -5px; width: 10px; height: 10px; background: var(--bg-card); border-right: 1px solid rgba(255,255,255,0.1); border-bottom: 1px solid rgba(255,255,255,0.1); transform: rotate(45deg); }
.dl-help:hover .dl-help-pop,
.dl-help:focus-within .dl-help-pop,
.dl-help.is-open .dl-help-pop { opacity: 1; visibility: visible; pointer-events: auto; transform: translate(-50%, 0); transition-delay: 0s; }

.dl-help-k { color: var(--accent); font-weight: 600; }
.dl-help-row { margin: 0 0 10px; }
.dl-help-row:last-of-type { margin-bottom: 0; }
.dl-help-sub { margin: 0 0 8px; }
.dl-help-code { display: block; margin: 8px 0 10px; padding: 10px 12px; background: rgba(0,0,0,0.4); border: 1px solid rgba(255,255,255,0.08); border-radius: 10px; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 12px; line-height: 1.6; color: var(--accent); white-space: nowrap; overflow-x: auto; -webkit-overflow-scrolling: touch; user-select: text; -webkit-user-select: text; }
.dl-help-code:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
```
**定位安全区（1080px 容器不溢出）**
- 气泡以**触发点中心**为锚水平居中（`left:50% + translateX(-50%)`）。触发点位于按钮行左起 208–264px，故其中心在**行中心偏左约 83–104px**（最坏情况按偏左 **120px** 预算）。
  桌面容器内容宽 1032px：触发点中心 ≈ 516 − 104 = **412px**，440px 气泡占 192–632px → 左余 192px、右余 400px，**远在容器内**。
  769px 视口：触发点中心 ≈ 384 − 104 = **280px**，气泡占 60–500px，仍在 24–745px 安全区内。
- 兜底：`width: min(440px, calc(100vw - 48px))`，任何宽度都不会横向溢出。
- **不被裁剪**：`.hero` 没有 `overflow: hidden`，`.hero::before` 是 `pointer-events:none` 的纯装饰径向渐变，气泡可越过 hero 下边界；`z-index: 40` 高于后续 `.mockup-section`（`.reveal` 的 transform 会生成层叠上下文，但层叠层级为 0 < 40），气泡下沿压到 mockup 区块之上仍然可见。
- 关闭态用 `visibility:hidden + pointer-events:none`（不是 `display:none`），因此有 180ms 淡出与上浮位移，且隐藏时不接收鼠标、不进无障碍树。
- **代码块**：等宽字体 + 深色代码底 + accent 文字；`white-space: nowrap` 保证命令始终是**一整行**（避免断行后复制出多余换行），超出部分在代码块内部横向滚动，不撑破气泡、不影响页面。

### 2.5 移动端（并入既有 `@media (max-width:768px)` 块，不新开断点）
```css
@media (max-width: 768px) {
  .dl-head { margin-bottom: 14px; gap: 8px; }
  .dl-head .dl-app { font-size: 15px; }
  .dl-actions { gap: 10px; }
  .dl-actions .btn-download { padding: 13px 22px; font-size: 15px; }
  .dl-tags { gap: 10px 14px; }

  /* 触发点：图标 + 文字，明确可点 */
  .dl-help-trigger { width: auto; height: 44px; padding: 0 14px; }
  .dl-help-label { display: inline; }

  /* 气泡 → 就地静态展开块：脱离 hover / focus-within 语义，纯由 .is-open 驱动 */
  .dl-help { display: contents; }                                   /* 包裹层退场，触发点与说明块都成为按钮行的直接 flex item */
  .dl-help-pop { position: static; order: 9; flex: 1 1 100%; width: 100%; max-width: none; margin-top: 2px; transform: none; opacity: 1; visibility: visible; pointer-events: auto; display: none; }
  .dl-help-pop::before { display: none; }                           /* 无锚点关系，去掉小箭头 */
  .dl-help:focus-within .dl-help-pop { display: none; }             /* 同特异性 + 后置，压掉桌面 :focus-within 规则 */
  .dl-help.is-open .dl-help-pop { display: block; }                 /* (0,3,0) 与上一条同级，靠源码顺序取胜 */
}
```
- `.dl-help { display: contents }` 让包裹层不生成盒子：触发点留在按钮行内（紧跟 MAC 按钮），说明块以 `order:9 + flex-basis:100%` 落到**按钮行的最后一行**、占满整宽 —— 即「点击就地展开」的静态说明块。
- 移动端无 hover，气泡语义整体作废：`:hover` / `:focus-within` 均不再能打开它，只有 `.is-open`（点击切换）能。
- 375px 下按钮行折成 2 行（Mac 版 + 安装说明 / Win 版 + GitHub），Win 版下方一行小字「敬请期待」，说明块再占一行；代码块在自身内部横向滚动 → 页面无横向滚动条。

## 3. 三种状态（+ 两个降级态）

| 状态 | 表现 |
| --- | --- |
| **① 默认态** | 公共信息行（应用名 + `v1.4.0` 胶囊 + `2026-09-24`）→ 按钮行（accent 实心 MAC / ghost 说明图标 / 虚线 WIN + 敬请期待 / 白面 GitHub）→ 元信息行（`1.8 MB DMG · macOS 12.0+ · Apple Silicon & Intel`）。气泡 `opacity:0 / visibility:hidden`。 |
| **② MAC 气泡展开态** | 触发点 hover 或键盘 focus 时：触发点转 accent 描边（`rgba(0,212,170,0.35)` + `rgba(0,212,170,0.08)` 底 + accent 图标），气泡在按钮行**上方** 14px 处淡入下沉（`translateY(6px→0)`，180ms）；带 10px 旋转方块小箭头（位于气泡下沿）指向触发点；【安装】/【首次打开】标签为 accent 600 字重，正文 `--text-secondary`；终端命令为深色代码块 + 等宽 + accent 文字，可整行选中。鼠标从图标移入气泡不中断（同一 hover 容器）。<br>**实现修正（v1.4.12）**：原设计向下弹出，实测在 900px 及更矮视口下会被视口下沿截断 129–309px（下载区位于 hero 下半部，下方空间不足）。改为向上弹出 + `max-height: calc(100vh - 40px)` 兜底，720/800/900/1080px 高度下均完整可见。 |
| **③ WIN 敬请期待态** | 与 Mac 版**同一套实心按钮**（同 `padding` / `border-radius:14px` / `font:16px 600` / 无可见边框；`.btn-download` 基类统一 `border:1px solid transparent` 保证三按钮等高 56px）+ 无 glow + 无 hover 位移/变色 + `cursor:not-allowed`；填充 `rgba(0,212,170,0.12)`、文字 `rgba(0,212,170,0.6)`，**仅整体降对比度**（不使用虚线边框、不使用 opacity 淡化整体）；文案 `Win 版`；「敬请期待」改为按钮正下方 12px `--text-dim` 小字（`.dl-win-note`，`aria-describedby` 关联）；`aria-disabled="true"`，不可点击、不在 Tab 序列中。 |
| ④ 降级 · 无安装包（`download` 为空） | MAC 按钮退化为 `.btn-secondary` + 「前往更新日志」+ `href="#versions"`，移除 `download` 属性；`#dl-size` 整条隐藏；公共信息行与 WIN/GitHub/说明气泡不受影响。 |
| ⑤ 降级 · 体积未知（`size` 缺失或 `-`） | `#dl-size` 整条 `hidden`（**绝不回落硬编码、绝不显示 `— DMG`**）；元信息行剩余两项居中，间距不变。当前 `versions[0].size` 就是 `-`，发版脚本写入后自动出现。 |
| ⑥ 降级 · `versions.json` 请求失败 | `catch` 分支：MAC 按钮 → `.btn-secondary` + 「前往更新日志」+ `href="#versions"`；`#dl-size` 隐藏；`#dl-version` / `#dl-date` 保持初始 `hidden`（不出现 `v—` 这类占位符）。不弹窗、不 toast。 |

## 4. JS 注入契约（替换 index.html 中 `fetch('versions.json')` 内的下载按钮段落）

```js
var v = data.versions[0];
var dlBtn  = document.getElementById('dl-btn');
var dlText = document.getElementById('dl-text');
var dlVer  = document.getElementById('dl-version');
var dlDate = document.getElementById('dl-date');
var dlSize = document.getElementById('dl-size');
var dlSizeText = document.getElementById('dl-size-text');

// ① 公共信息行：应用名是常量，版本 / 日期由数据注入
if (dlVer)  { dlVer.textContent = 'v' + v.version; dlVer.hidden = false; }
if (dlDate) { dlDate.textContent = v.date || '';   dlDate.hidden = !v.date; }

// ② 体积：唯一来源 versions.json[0].size；"-" 或空 → 整条隐藏
var size = String(v.size == null ? '' : v.size).trim();
var hasSize = size !== '' && size !== '-';
if (dlSizeText) dlSizeText.textContent = size;
if (dlSize) dlSize.hidden = !hasSize;

// ③ MAC 主按钮：文案静态（不含版本与体积），只有 href / download 由数据驱动
if (v.download) {
  dlBtn.href = v.download;
  dlBtn.setAttribute('download', v.download);
} else {
  dlBtn.href = '#versions';
  dlBtn.removeAttribute('download');
  dlBtn.classList.remove('btn-primary');
  dlBtn.classList.add('btn-secondary');
  if (dlText) dlText.textContent = '前往更新日志';
  if (dlSize) dlSize.hidden = true;
}
```
`catch` 分支追加：
```js
if (dlSize) dlSize.hidden = true;
if (dlBtn) { dlBtn.href = '#versions'; dlBtn.removeAttribute('download'); }
if (dlText) dlText.textContent = '前往更新日志';
```
### 4.1 发版数据契约：`size` 每次发版自动写入（release.sh 改造）

**现状缺口（必须修）**：`ComateNotch/release.sh` 的 Step 3 里，`node -e` 新增版本条目时把 `size` **写死为 `'-'`**，且当版本已存在时直接 `process.exit(0)` 跳过。结果是：**每次发版后官网体积都不会更新**（当前 `versions[0]` 就还是 `'-'`，而 `ComateHUD-1.4.0.dmg` 实际 1887772 字节 ≈ `1.8 MB`）。这正是用户「以后发版后都需要默认更新」诉求的根因。

**唯一真值**：`versions[0].size`（形如 `1.8 MB`）。官网任何位置不得出现写死的体积或版本号；`~` 前缀允许保留（沿用 1.3.0 的 `~1.4 MB` 写法），原样展示，不做二次格式化。

**改造规格（`ComateNotch/release.sh`，Step 2 之后 / Step 3 之前插入）**
```bash
# --- Step 2.5: 计算 DMG 实际体积（官网体积的唯一真值来源）---
SIZE_STR="-"
if [[ -f "$DMG_DST" ]]; then
  DMG_BYTES=$(stat -f%z "$DMG_DST")            # macOS 用 -f%z；GNU 环境为 stat -c%s
  SIZE_STR=$(awk -v b="$DMG_BYTES" 'BEGIN{
    if (b >= 1048576)      printf "%.1f MB", b/1048576;
    else if (b >= 1024)    printf "%.0f KB", b/1024;
    else                   printf "%d B", b;
  }')
  echo "✅ 安装包体积: $SIZE_STR ($DMG_BYTES bytes) -> versions.json"
else
  echo "⚠ 未找到 DMG，size 保持 '-'（官网将隐藏体积行，不写假数据）"
fi
```
并把 Step 3 的 `node -e` 改为：
```js
// 版本已存在时：只回填 size（幂等重跑），不重复插入
var idx = data.versions.findIndex(function (x) { return x.version === '${VERSION}'; });
if (idx >= 0) {
  data.versions[idx].size = '${SIZE_STR}';
  console.log('✅ 已回填 v${VERSION} size -> ${SIZE_STR}');
} else {
  data.versions.unshift({
    version: '${VERSION}',
    build: ${BUILD_NUM},
    date: new Date().toISOString().split('T')[0],
    platform: 'macOS',
    size: '${SIZE_STR}',                       // ← 不再写死 '-'
    download: 'ComateHUD-${VERSION}.dmg',
    minOS: '12.0',
    changelog: [{ type: 'new', text: '待填写更新内容' }]
  });
}
data.latest = '${VERSION}';
fs.writeFileSync('versions.json', JSON.stringify(data, null, 2) + '\n');
```

**边界规则**
| 情况 | `size` 取值 | 官网表现 |
| --- | --- | --- |
| DMG 存在，≥ 1 MiB | `1.8 MB`（1 位小数，1024 进制） | 元信息行首项显示「`1.8 MB` DMG」 |
| DMG 存在，< 1 MiB | `932 KB`（整数） | 同上，原样展示 |
| DMG 缺失（构建失败） | 保持 `'-'` | `#dl-size` 整条隐藏（降级态⑤），**不显示假数据** |
| 历史条目（1.0.0 / 1.1.0） | 维持原值不动 | 仅影响更新日志，不影响下载区 |

**一次性回填（本次改造需顺带完成）**：`ComateHUD/versions.json` 的 `versions[0]`（1.4.0）`size` 由 `'-'` 改为 `'1.8 MB'`，与 `ComateHUD-1.4.0.dmg`（1887772 字节）一致；否则本次上线官网体积仍为空。

**气泡交互 JS（新增，独立 IIFE）**
```js
(function () {
  var help = document.getElementById('dl-help');
  var trig = document.getElementById('dl-help-trigger');
  if (!help || !trig) return;
  var canHover = window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  function setExpanded(on) { trig.setAttribute('aria-expanded', on ? 'true' : 'false'); }
  if (canHover) {                                   // 桌面：hover / focus 由 CSS 打开，这里只同步 aria
    help.addEventListener('mouseenter', function () { setExpanded(true); });
    help.addEventListener('mouseleave', function () { setExpanded(help.classList.contains('is-open')); });
    trig.addEventListener('focus', function () { setExpanded(true); });
    trig.addEventListener('blur',  function () { if (!help.classList.contains('is-open')) setExpanded(false); });
  }
  trig.addEventListener('click', function () {      // 点击切换：移动端主路径；桌面为无害的空操作
    var open = !help.classList.contains('is-open');
    help.classList.toggle('is-open', open);
    setExpanded(open);
  });
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    var active = document.activeElement;
    if (!help.classList.contains('is-open') && !(active && help.contains(active))) return;
    help.classList.remove('is-open');
    setExpanded(false);
    if (active && help.contains(active) && active.blur) active.blur();   // 释放 :focus-within
  });
})();
```
- **不用 `mouseenter` 打开、`click` 关闭**那套写法：触屏上 tap 会先 focus 再 click，必然自相矛盾。这里桌面交给 CSS、移动端只认 `.is-open`，两条路径互不干扰。
- `Escape` 必须同时 `blur()`：桌面气泡是靠 `:focus-within` 打开的，只移除 class 关不掉。

## 5. 移动端与键盘可达

**移动端（≤768px，无 hover）**：触发点从 44×44 图标变为「图标 + 安装说明」胶囊按钮（44px 高，满足触控尺寸）；点击在按钮行末尾就地展开静态说明块，再点收起；`aria-expanded` 同步 true/false。说明块不是浮层、不带阴影遮挡、不锁滚动。

**键盘可达**：`Tab` 聚焦触发点 → `:focus-visible` 出现 accent 外描边（`outline: 2px solid var(--accent); outline-offset: 2px`）且气泡展开；再 `Tab` 落到说明块内的 `<code tabindex="0">`（因为它在 `.dl-help` 内，`focus-within` 保持展开），可用 `Shift + ←/→` 选中命令文本；`Esc` 关闭气泡并归还焦点；`Shift+Tab` 离开 `.dl-help` 后气泡自动关闭。语义：`<button aria-expanded aria-controls>` + `<div role="region" aria-label>`；关闭态 `visibility:hidden` 使其不进入无障碍树。WIN 按钮用 `aria-disabled="true"` 且不可聚焦 —— 死控件不应占用 Tab 序列，而「敬请期待」文字仍在阅读顺序里可被读屏读到。

## 6. 与既有代码的衔接（改动点清单，行号以当前 index.html 为准）

| 位置 | 动作 |
| --- | --- |
| CSS 第 55–72 行 | 保留 `.hero-actions` / `.btn-download` / `.btn-primary` / `.btn-secondary` / `.hero-tags` 不动；**替换** `.btn-coming` 的 `{ opacity:.5; cursor:not-allowed; pointer-events:none }` 为第 2.2 节写法；追加 `.dl-*` 全部新规则 |
| CSS 第 64–65 行 `.hero-tags` | 保留基类，`.hero-tags span` 的 12px/`--text-dim` 继续生效（与 `.dl-tag` 同值，无冲突） |
| CSS 第 326–341 行 `@media (max-width:768px)` | 在块内追加第 2.5 节规则，**不新开断点** |
| HTML 第 367–385 行 | 用第 1 节结构整体替换；`id="download"` 移到 `.dl-block`；三个按钮文案/图标按新结构；`.hero-tags` 内 emoji 换成内联 SVG 并加 `#dl-size` |
| HTML 第 378–381 行 `.release-toggle` | 结构保留，仅把 inline `style="margin-top:12px"` 移除（由 `.dl-tags { margin-top:16px }` 与既有 `.release-toggle` 间距统一控制，避免双份间距） |
| JS 第 613–625 行 | `fetch` 成功分支里「Hero download button」段落按第 4 节重写（现有 `dlText.textContent = '下载 Comate HUD v' + v.version + ' (' + v.size + ')'` 整段删除）；`rn-summary` / `release-body` / `version-list` 逻辑**不动**；第 661 行 `catch` 分支按第 4 节追加 |
| JS 第 939–947 行下载计数 | **不动**：仍以 `#dl-btn` 的 `.dmg` 结尾判定是否计数；降级态按钮指向 `#versions` 时自然不计数 |
| 新增 | 气泡交互 IIFE（第 4 节） |
| `ComateNotch/release.sh` Step 3 | `size` 不再写死 `'-'`：插入 Step 2.5 计算 DMG 字节数并格式化，版本已存在时改为**回填 size**（幂等重跑），见第 4.1 节 |
| `ComateHUD/versions.json` | `versions[0]`（1.4.0）`size` 由 `'-'` 回填为 `'1.8 MB'`（1887772 字节），见第 4.1 节 |
| 全站 | `#download` 锚点、页脚链接、导航 `.btn-sm` 均无需改动 |

**不要做的事**：不要给下载区加 `.reveal`（hero 在首屏，淡入会导致 CTA 迟到）；不要给气泡加 `position: fixed` 或 JS 定位；不要引入任何图标字体 / 图标库 / 外部字体；不要在 HTML 里写死版本号或体积。

## 7. Acceptance Contract

- [ ] 源码中不存在硬编码的版本号与体积（搜 `1.4 MB` / `1.8 MB` / `v1.4.0` 应只命中 `versions.json`，index.html 内零命中）；`#dl-text` 文案不含版本与体积
- [ ] 版本号、发布日期、体积三者均来自 `versions[0]`；把 `versions.json` 的 `size` 改成 `12.4 MB`、`version` 改成 `1.12.3` 后刷新，公共信息行与元信息行自动跟随，**布局不破**（胶囊变宽、行不折断）
- [ ] 体积渲染在**按钮之外**（元信息行），与 `macOS 12.0+`、`Apple Silicon & Intel` 同一行；emoji 全部消失，三个图标均为手写内联 SVG
- [ ] `size` 为 `-` / 空时 `#dl-size` 整条不显示，且页面不出现 `— DMG` 或任何回落的旧体积
- [ ] 按钮共三个且层级清晰：MAC = `.btn-primary`（唯一 accent 实心 + glow）；WIN = `.btn-coming`（与 Mac 版同一套实心按钮，仅降对比度 + 无 glow + `cursor:not-allowed` + `aria-disabled`；「敬请期待」在按钮下方小字，**未使用虚线边框、未使用 opacity 做不可用态**）；GitHub = `.btn-secondary`；三按钮等高同圆角；说明触发点为 44×44 ghost 图标
- [ ] WIN 按钮点击无任何反应、不进 Tab 序列、无 hover 视觉反馈
- [ ] 触发点 hover 时气泡淡入上浮（180ms）且带指向触发点的小箭头；鼠标从图标移入气泡**不消失**，气泡内文本可整段选中
- [ ] 气泡内容与用户原话一致：【安装】、【首次打开】、方式一（「系统设置 → 隐私与安全性 → 安全性 → 仍要打开」放行路径，右键打开在新版 macOS 已无「打开」选项）、方式二 + 命令 `xattr -dr com.apple.quarantine /Applications/ComateHUD.app`；命令为等宽字体 + 深色代码块 + 内部横向滚动，**始终一整行**（复制不产生多余换行）
- [ ] 气泡在 1080 / 1024 / 900 / 769px 宽度下均不横向溢出、不被 hero 裁剪、不被下方 mockup 区块遮挡（`z-index:40` 生效）
- [ ] 键盘：`Tab` 到触发点即展开（`focus-visible` accent 外描边）、`Tab` 可进入 `<code>` 选中命令、`Esc` 关闭并归还焦点、`aria-expanded` 与可见性同步
- [ ] 移动端（≤768px，含 375px）：触发点显示「图标 + 安装说明」文字；点击就地展开静态说明块、再点收起；`:hover`/`:focus-within` 在移动端**不能**打开气泡
- [ ] 375px 无横向滚动条（仅代码块内部可横向滚动）；按钮行折行后不溢出容器
- [ ] 无任何新增外部请求（无 CDN / 字体 / 图标库 / 图片）；源码不含 `oklch(` / `color-mix(` / `@layer`
- [ ] 颜色只来自既有 `:root` 变量与 `rgba(255,255,255,0.03~0.16)` / `rgba(0,0,0,0.4)` / `rgba(0,212,170,0.08~0.35)`
- [ ] 下载计数逻辑仍正常（点真实 DMG 才 +1）；`#download` 锚点（导航 + 页脚）跳转位置正确，不被固定导航遮挡
- [ ] 移动端规则写在既有 `@media (max-width:768px)` 块内，未新增断点；未改动 `index.html` 既有 token、既有类名语义、hero 其他部分与其他区块
- [ ] **发版自动更新**：`bash ComateNotch/release.sh <ver> <build>` 跑完后，`versions.json` 的 `versions[0].size` 等于 DMG 实际体积的格式化值（1.4.0 为 `1.8 MB`），**不再是 `'-'`**；重复跑同一版本号不新增条目、只回填 size
- [ ] 构建失败 / DMG 缺失时 `size` 保持 `'-'`，官网体积行整条隐藏且**不出现任何假数据**
- [ ] `versions.json` 的 `versions[0].size` 已回填为 `1.8 MB`，与 `ComateHUD-1.4.0.dmg`（1887772 字节）一致
- [ ] 把 `size` 改成 `12.4 MB` 后刷新，元信息行首项变为「`12.4 MB` DMG」，行宽与基线不跳变

---

# 全站文案精简 + 排版节奏 · 设计规范

> **范围**：`ComateHUD/index.html` 全站**文案**与全站**垂直节奏 / 网格间距 / 字号行高**。
> **不在范围内**：hero 下载区 `#download` 内部（已由上文「下载区块 · 设计规范」覆盖）、`#appstats` 的数据渲染逻辑（已由上文「应用统计区块 · 设计规范」覆盖）、更新日志文案（来自 `versions.json`，非手写）。
> **视觉稿**：`docs/designs/references/copy-rhythm.svg`（间距刻度 / 区块节奏 / compat 标签带 / 功能卡解剖，四联图）。

## 0. Design Contract

**目标**：把「信息流偏密」改成「一眼扫过、留白说话」。两条硬指标同时成立 ——
1. **文案**：中等力度精简。**不砍信息点**（数字 / 功能名 / 机制说明全留），只砍重复表达、可从上下文推断的废话、过度承诺的形容词。2 句压 1 句，3 并列压 2。
2. **排版**：正文行高 1.6 → 1.7~1.75；区块上下 padding 80 → 112；网格 gap 16~20 → 20~28；卡片内边距 +4~8px。**信息密度下降，信息量不变。**

### 硬约束（沿用既有约定）
- 纯静态单文件页，零外部资源（无 CDN / 无外部字体 / 无图标库 / 无图片，图标一律手写内联 SVG）。
- 禁用 `oklch()` / `color-mix()` / `@layer`；颜色只用既有 `:root` 变量与既有白/黑/accent 透明度写法。
- 移动端规则并入既有 `@media (max-width:768px)` 块，**不新开断点**。
- 不新增字体族（沿用 `-apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC"`）。
- 不改 `.reveal` 观察器参数（`threshold:0.1` / `rootMargin:'0px 0px -40px 0px'`）。
- **锚点集合（1.5 修订后）**：`#features` / `#lights` / `#tech` / `#appstats` / `#powered` / `#versions` / `#wishwall` / `#download`。**`#compat` 已删除**（并入 `#tech`，导航项一并移除；页脚从未引用它）。

### 复用既有 token（不新增颜色）
`--bg`(#0a0a0f) `--bg-card`(#111118) `--bg-card-hover` `--text`(#f5f5f7) `--text-secondary`(#8e8e93) `--text-dim`(#55555d) `--accent`(#00d4aa) `--accent-glow` `--radius`(20px) `--max-w`(1080px)
中性色仅 `rgba(255,255,255,0.03 / 0.06 / 0.08 / 0.1)`。

### 不做什么（明确否决项）
| 否决 | 理由 |
| --- | --- |
| 不加分隔线 / 不加背景分区 / 不加装饰图形 | 节奏**只靠留白层级**说话，与页面「最克制」的既有风格一致。加线会把「留白不足」换成「线条噪音」。 |
| 不扩成 9 张功能卡 | 见 §3：9 卡在 3 列网格下是 3 行，比 6 卡**更密**，与诉求相反。 |
| ~~不把 `#compat` 并入 `#tech` 删掉 section~~ | **1.5 修订作废**：用户明确要求「兼容性不作为单独模块，合并进技术栈」。`#compat` section 已删除，标签带挂在 `#tech` 的 `.arch-detail` 之后（`.compat-strip { margin-top: 48px }`）。页脚无 `#compat` 链接，不会断锚。 |
| 不动 `.compat-table` CSS 规则 | 它被 `#appstats` 的「今日活跃明细」表复用（`table class="compat-table stats-table"`），删除会连带破坏 appstats。只替换 `#compat` 里的 HTML。 |
| 不改 `.reveal` 参数、不加新的 IntersectionObserver | 现有观察器按 `.reveal` 类扫描，新增/删除区块无需改 JS。 |
| 不精简更新日志文案 | 来自 `versions.json`，属数据不属文案。 |

---

## 1. 文案精简总则（5 条）

| # | 规则 | 示例 |
| --- | --- | --- |
| 1 | **删版本溯源前缀**：`v1.3.0 新增：` 交给更新日志，正文不重复 | 「任意悬浮模式」「外接显示器适配」两卡各去掉 `v1.3.0 新增：` |
| 2 | **删过度承诺 / 过度形容词** | `柔和而有存在感`、`安静守候`、`紧急`、`轻量无冗余`、`不必从零搭建`、`定当持续更新为报` |
| 3 | **删可从上下文推断的废话** | 「未读**消息**角标」中的「消息」（区块标题 + 铃铛图标已承载）；「100% Swift + SwiftUI **构建**」的「构建」 |
| 4 | **2 句压 1 句 / 3 并列压 2** | powered 免责声明 2 句 → 1 句；powered 卡片「它做的」4 项并列 → 3 项 |
| 5 | **保留全部具体信息** | 数字（15 分钟 / 2s / 30s / 5 轮 / 120fps / 1.6.17 / macOS 12.0）、功能名（NSPanel / SQLite / URLSession / Deeplink）、机制（定时轮询 / 异步队列 / 读写权限策略 / 失败重试）—— 一个不删 |

### 篇幅硬指标（可验收）

| 对象 | 上限 | 换算依据 |
| --- | --- | --- |
| 功能卡正文 `.feature-card p` | **≤ 2 行 / ≤ 32 字** | 1080px 三列卡内容宽 `(1032−2×28)/3 − 2×32 = 261px`，15px 中文 ≈ 17 字/行 |
| 区块副标题 | **≤ 2 行 / ≤ 64 字** | `max-width:560px` @16px ≈ 34 字/行 |
| 架构条目 `.arch-detail li` | **≤ 2 行 / ≤ 84 字** | 内容宽 `720 − 2×36 = 648px` @14px ≈ 44 字/行 |
| 全站总字数 | **−18% ~ −25%** | 不含 JS 渲染的更新日志 |

> 这三条是本次精简的**验收口径**：正文一旦超过 2 行，说明还有可砍的重复表达。

---

## 2. 逐区块文案对照表（原文 → 精简后）

> 「原文」逐字取自当前 `index.html`。「精简后」可直接作为实现文案。

### 2.1 hero（badge / h1 / 副标题 / 灯图例）

| 位置 | 原文 | 精简后 | 动作 |
| --- | --- | --- | --- |
| badge | `macOS 原生 · Swift · SwiftUI` | 不变 | 3 个具体词，无水分 |
| h1 | `Comate HUD` + `让 AI 干活，你只管看灯` | 不变 | 已是全站最短最有力的一句 |
| 副标题 | `一款常驻 macOS 刘海区的轻量状态指示器，为 WPS Comate 而生。`<br>`无需打开主窗口，任务状态一目了然。` | `常驻 macOS 刘海区的状态指示器，为 WPS Comate 而生。`<br>`不用打开主窗口，状态抬眼即知。` | 删 `一款`（虚词）、`轻量`（过度形容词）、`任务`（可推断）；`一目了然` → `抬眼即知`（与 h1「看灯」呼应，且更短） |
| 灯图例 | `空闲` / `已完成` / `工作中` / `等待确认` | 不变 | 2~4 字，已是极限 |

### 2.2 mockup-section

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| `.desktop-hint` | `把鼠标移到刘海上，面板会像真机一样展开` | `悬停刘海，面板会像真机一样展开` |

### 2.3 features「核心功能」

| 卡片 | 原文 | 精简后 |
| --- | --- | --- |
| 实时状态灯 | `四种状态灯常驻刘海：灰灯空闲、绿灯已完成、黄灯工作中、红灯等待确认。抬眼即知。` | `四种状态灯常驻刘海。抬眼即知，不用切窗口。` |
| 任务面板 | `悬停刘海展开最近任务与耗时，右键可调展示条数；点击任意任务行，直达对应会话窗口。` | `悬停展开最近任务与耗时，点击任务行直达会话窗口；右键可调条数。` |
| 消息中心 | `未读消息角标实时更新，点击铃铛直达消息中心。` | `未读角标实时更新，点铃铛直达消息中心。` |
| 额度用量 | `实时显示 AI 用量消耗，支持日/月周期切换。` | `实时显示 AI 用量，支持日/月切换。` |
| 任意悬浮模式 | `v1.3.0 新增：图标 + 状态灯常驻桌面任意位置，hover 展开面板，可跨屏拖拽。` | `图标 + 状态灯常驻桌面任意位置，hover 展开，可跨屏拖拽。` |
| 外接显示器适配 | `v1.3.0 新增：插拔显示器自动重新定位到主屏，无需重启。` | `插拔显示器自动重新定位主屏，无需重启。` |

**关键动作：与 `#lights` 去重**。卡片 1 原本把 4 种灯色全列了一遍，而下方 `#lights` 区块正是逐色解释 —— 同一信息出现两次。卡片 1 只保留「四种状态灯常驻刘海」这一**结论**，颜色枚举交给 `#lights`（它有声光电的视觉承载）。这是本次最大的一处去重（−20 字）。

### 2.4 lights-section「状态含义」

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| 副标题 | `每种状态都有独特的灯色与节奏，让你在余光中就能感知 AI 在干什么。` | `每种状态有独特的灯色与节奏，余光就能感知 AI 在干什么。` |
| 空闲 | `⚪️ 空闲` / `没有进行中的任务。灯常亮，安静守候。` | `空闲` / `没有进行中的任务。灯常亮。` |
| 已完成 | `🟢 已完成` / `任务刚跑完。绿灯保持 15 分钟，期间触发新对话会继续顺延。` | `已完成` / `任务刚跑完。绿灯保持 15 分钟，期间有新对话则顺延。` |
| 工作中 | `🟡 工作中` / `AI 正在执行任务。呼吸式慢闪，柔和而有存在感。` | `工作中` / `AI 正在执行任务。呼吸式慢闪。` |
| 等待确认 | `🔴 等待确认` / `AI 需要你的决策。快闪，紧急提醒。` | `等待确认` / `AI 需要你的决策。快闪提醒。` |

**关键动作：删掉 `<h4>` 里的 emoji**。`.light-orb` 就在正上方，灯色已由视觉承载，`⚪️🟢🟡🔴` 是纯冗余（同时与「下载区移除 emoji」的既有决定保持一致）。`15 分钟` 这个数字必须保留。

### 2.5 how-section「使用流程」→ 删除（详见 §3）

### 2.6 tech-section「技术栈」

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| 副标题 | `100% Swift + SwiftUI 构建，无 Electron、无 WebView、无第三方框架。` | `100% Swift + SwiftUI，无 Electron、无 WebView、无第三方框架。` |
| 开发语言 note | `Apple 推荐的现代系统语言` | `Apple 官方语言` |
| UI 框架 note | `声明式 UI，原生渲染` | 不变 |
| 窗口管理 note | `刘海区域精确贴合` | 不变 |
| 数据读取 note | `读取 Comate 聊天记录库` | 不变 |
| 网络通信 note | `云端消息中心 & 用量 API` | 不变 |
| 系统集成 note | `wpscomate:// 协议调起 Comate` | 不变 |
| 构建产物 note | `arm64 + x86_64 双架构 lipo` | 不变 |
| 打包分发 note | `脚本一键构建，拖拽即装，轻量无冗余` | `脚本一键构建，拖拽即装` |
| 架构标题 | `🏗 架构设计` | `架构设计`（去 emoji，与全站一致） |

**架构设计 5 条**（保留 5 条，只压措辞；数字与机制全留）

| 组件 | 原文 | 精简后 |
| --- | --- | --- |
| ComateStore | `数据层：2s 定时轮询本地 SQLite，30s 刷新云端额度与消息中心，异步队列查询避免主线程阻塞` | `数据层：2s 轮询本地 SQLite，30s 刷新云端额度与消息；异步队列查询，不阻塞主线程` |
| NotchPanel | `窗口层：自定义 NSPanel 永远在主屏幕最顶层，精确计算刘海偏移量，展开/收起动画 120fps` | `窗口层：NSPanel 常驻主屏最顶层，精确计算刘海偏移；展开/收起 120fps` |
| NotchRootView | `UI 层：SwiftUI 声明式布局，收起态为紧凑胶囊，展开态为任务列表 + 额度面板` | `UI 层：SwiftUI 声明式布局；收起为紧凑胶囊，展开为任务列表 + 额度面板` |
| SessionJournal | `日志层：解析 Comate 本地 session journald 文件，提取最近 5 轮对话摘要作为任务描述` | `日志层：解析本地 session journald，取最近 5 轮对话摘要作为任务描述` |
| UsageAPI | `用量层：通过 wps_sid Cookie 调用 comate.wps.cn 接口，获取日/月额度使用情况` | `用量层：以 wps_sid Cookie 调用 comate.wps.cn，获取日/月额度` |

### 2.7 compat-section「兼容性」→ 表格降级为一行标签带（详见 §4）

### 2.8 version-section「更新日志」

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| h2 | `每个版本改了什么` | 不变 |
| 版本条目正文 | JS 从 `versions.json` 渲染 | **不改**（数据非文案） |

### 2.9 appstats-section「应用统计」

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| h2 | `谁在用 Comate HUD` | 不变 |
| 副标题 | `安装设备每天上报一次活跃，按用户去重统计。` | 不变（一句话把口径说清，无水分） |
| 区块标题 1 | `近 30 日活跃用户趋势` | `近 30 日活跃趋势` |
| 区块标题 2 | `版本分布（近 30 日活跃用户）` | `版本分布`（「活跃用户」已由副标题的口径声明与标题 1 承载） |
| 区块标题 3 | `今日活跃明细` | 不变 |

### 2.10 powered-section「能力提供」

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| 副标题 | `不用会写代码——你负责想，Comate 负责做。从一个念头，到一个能上线的复杂应用。` | `不用会写代码——你负责想，Comate 负责做。从一个念头，到上线。` |
| 卡 1 标题 | `「给部门做个内部报修系统」` | 不变 |
| 卡 1 场景 | `要填单、要能看进度、要只有本部门能看，数据还得存下来。` | `要填单、要看进度、要只有本部门可见，数据得存下来。` |
| 卡 1 它做的 | `它做的：云端建表 + 读写权限策略 + 前端表单与列表 + 部署上线。你不用建库，也不用写接口。` | `它做的：云端建表 + 权限策略 + 表单与列表 + 部署上线。不用建库，不用写接口。` |
| 卡 2 标题 | `「多维表里的工单，超时了自动催到 IM」` | `「多维表工单超时，自动催到 IM」` |
| 卡 2 场景 | `按项目负责人私聊提醒，几点催、催几轮，我说了算。` | `按项目负责人私聊提醒，几点催、催几轮我说了算。` |
| 卡 2 它做的 | `它做的：多维表数据源接入 + IM 消息推送 + 定时任务 + 失败重试。跨系统的活，它自己接。` | `它做的：多维表接入 + IM 推送 + 定时任务 + 失败重试。` |
| 卡 3 标题 | `「把散在邮件、云文档里的数据拼成经营看板」` | `「把邮件、云文档的数据拼成经营看板」` |
| 卡 3 场景 | `每周人工汇总要半天，还总担心漏。` | `每周人工汇总要半天，还容易漏。` |
| 卡 3 它做的 | `它做的：多源采集 + 清洗聚合 + 可视化看板 + 定时回写云文档。半天的人工，变成自动跑。` | `它做的：多源采集 + 清洗聚合 + 看板 + 定时回写云文档。半天的人工，变成自动跑。` |
| 总结句 | `这个官网、你正在用的 Comate HUD，都是这么来的。还想要别的？去许愿墙说一声。` | `这个官网、你正在用的 Comate HUD，都这么来的。还想要别的？去许愿墙说一声。` |
| powered-card 正文 | `Comate HUD 基于 WPS Comate 的应用开发能力构建。借助它开放的本地数据库读取、Deeplink 调起、OAuth 认证等接口，HUD 实现了与 Comate 桌面客户端的深度集成——读取任务状态、打开会话窗口、获取未读消息、查询用量额度，接入即可用，不必从零搭建。` | `Comate HUD 基于 WPS Comate 的应用开发能力构建。借助其开放的本地数据库读取、Deeplink 调起、OAuth 认证等接口，实现了与 Comate 桌面客户端的深度集成——读取任务状态、打开会话窗口、获取未读消息、查询用量额度。` |
| 免责声明 | `Comate HUD 是一个独立的 macOS 原生应用，不属于 WPS 或 WPS Comate 的官方产品。它由社区开发者基于 Comate 开放能力构建，以第三方应用形式运行。` | `Comate HUD 是独立的 macOS 原生应用，非 WPS 官方产品，由社区开发者基于 Comate 开放能力构建。` |

**免责声明是唯一「必须保量」的一段**：2 句压 1 句，但 4 个法律事实（独立 / 非官方 / 社区开发者 / 基于开放能力）一个不能少。删掉的是「以第三方应用形式运行」这句重复表述（与「独立」同义）。

### 2.11 wish-section「许愿反馈」

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| 副标题 | `留下你的名字，提交你的愿望和建议，所有留言会在弹幕中展示。` | `留下名字，提交愿望与建议，留言会在弹幕中展示。` |
| 名字 placeholder | `你是谁（英雄请留名，定当持续更新为报）` | `你是谁（英雄请留名）` |
| 文本域 placeholder | `想法建议你尽管提，我...让Comate来改 >_<` | `想法建议尽管提，交给 Comate 来改` |

`定当持续更新为报` 是**过度承诺**，直接删；文本域的玩笑话保留语气但压短（并顺手修掉 `我...` 的省略号与缺失空格）。

### 2.12 footer

| 位置 | 原文 | 精简后 |
| --- | --- | --- |
| 第 1 行 | `Comate HUD — 为 WPS Comate 而生的 macOS 状态指示器` | 不变 |
| 第 2 行 | `macOS 12.0+ · Apple Silicon &amp; Intel · Swift · SwiftUI` | `macOS 12.0+ · Swift + SwiftUI`（架构信息已由 §4 的 compat 标签带承载，此处去重） |
| 第 3 行 | 下载 · 许愿反馈 · GitHub | 不变 |

### 2.13 nav

8 个锚点 + 下载按钮 + PV 全部不变。**`#how` 从来没有导航入口**，删除 `how-section` 不影响任何锚点。

---

## 3. features 吸收 how-section：判断与理由

### 结论：**不扩成 9 张卡，也不保留「3 步」引导条 —— 完全解散，只并入 1 个短句。**

### 理由

**理由 1 · 内容类型不同，混放会摧毁「一眼扫过」**
6 张卡回答「它**能做什么**」（能力矩阵：可并列、可乱序、可任意增删）；3 步回答「我**该怎么做**」（线性流程：有先后顺序）。把两者放进同一个 3 列网格，用户的扫描模式会从「一眼扫过找关键词」退化成「逐条读完才发现这是流程」—— 直接抵消本次「降低拥挤感」的目标。

**理由 2 · 9 张卡不是「不拥挤」，是更拥挤**
6 卡在 3 列网格下是 2 行；9 卡是 3 行。多出整整一行卡片（≈ 300px），视觉密度**上升** 50%，与诉求方向相反。

**理由 3 · 3 步里有 2/3 是重复内容（逐句审计）**

| how 原文（逐句） | 判定 | 去向 |
| --- | --- | --- |
| 步骤 1 标题 `安装并启动` | 删 | — |
| `将 ComateHUD.app 拖入「应用程序」文件夹，双击启动。` | **删（完整重复）** | 下载区「安装说明」气泡【安装】已逐字覆盖 |
| `HUD 自动常驻刘海区` | **删（重复）** | 卡片 1「四种状态灯常驻刘海」 |
| `首次启动请允许辅助功能权限。` | **删（重复）** | §4 compat 标签「辅助功能权限」 |
| 步骤 2 标题 `在 Comate 中发起任务` | 删 | — |
| `正常使用 WPS Comate 发起任务——写代码、生成文档、分析数据。` | **删（废话）** | 产品前提，读者已知；「写代码/生成文档/分析数据」是举例堆砌 |
| `HUD 自动通过 SQLite 读取本地任务状态，无需额外配置。` | **删（重复）** | tech「数据读取 / SQLite（本地）」+ 卡片 2 已述「自动」 |
| 步骤 3 标题 `看灯、展开、点击` | 删 | — |
| `看灯知道状态，悬停展开看详情，点击直接跳转。` | **删（重复）** | 就是卡片 1 + 卡片 2 的重述 |
| `不需要切窗口，不需要查日志，AI 在干什么一目了然。` | **✅ 保留 1 句** | 并入卡片 1 收尾 → `抬眼即知，不用切窗口。` |

**审计结果：3 步 × 3 句 = 9 句，其中 8 句可删，1 句有价值。** 这 1 句已按上表并入「实时状态灯」卡（该卡因此从「颜色枚举」换成「结论 + 收益」，见 §2.3）。`how-section` 的 `<section>`、`.steps` / `.step` / `.step-num` / `.step-content` 规则**整块删除**（全站无其他引用）。

### 备选方案（默认不做，供二次决策）
如果你仍希望保留「上手路径」这一拍，**正确形态不是 3 张卡，而是 features 网格下方的一行极简流程带**：
- 内容：`安装并启动 → 发起任务 → 看灯展开点击`，3 段，每段 ≤ 6 字，**无段落文字、无图标、无卡片**
- 形态：单行 flex、居中、`gap: 24px`、13px `--text-dim`、段间用 `→`（`rgba(255,255,255,0.16)` 色）分隔，整体高 ≈ 20px
- 定位：作为 features 的「脚注」而非「第二个区块」，不加 `.reveal`、不加 section-label、不加 h2

代价：多 20px 高度与一次「区块内第二拍」的节奏切换；收益：新用户知道从哪开始（但 hero 的下载按钮 + 安装说明气泡其实已经回答了这个）。**判断：收益不抵代价，默认不做。**

---

## 4. compat 一行标签带的形态

### 保留的信息（5 项，全部是不可推断的硬门槛）

| 原表格行 | 原「要求」列 | 新标签文案 | 图标（手写内联 SVG） |
| --- | --- | --- | --- |
| 操作系统 | macOS 12.0 (Monterey) 或更高版本 | `macOS 12.0+` | apple（`fill`，直接复用导航 `.mb-apple` 的 path） |
| 处理器架构 | Apple Silicon (M1/M2/M3/M4) & Intel x86_64 | `Apple Silicon & Intel` | chip（`stroke`，复用 `.dl-tag` 的芯片 path） |
| 设备机型 | MacBook Pro / Air / iMac 系列（含刘海屏与非刘海屏机型） | `MacBook / iMac（含非刘海）` | laptop（`stroke`：`rect x=3 y=5 w=18 h=12 rx=2` + `M2 19h20`） |
| 辅助功能权限 | 系统设置 → 隐私与安全性 → 辅助功能 | `辅助功能权限` | shield-check（`stroke`） |
| WPS Comate | 建议 1.6.17 或更高版本 | `WPS Comate 1.6.17+` | puzzle（`stroke`） |

### 删除的信息（2 项 + 整列）

| 删除项 | 理由 |
| --- | --- |
| 原「网络连接」行：`建议保持网络连接畅通，以获取消息中心与额度信息` | 「建议保持畅通」是软建议、无门槛值；且「本地优先」这个真正有价值的信息已由 tech 的「数据读取 / SQLite（本地）」承载 |
| 原「状态」列：`✓ 支持` / `✓ Universal Binary` / `✓ 刘海区 & 菜单栏 HUD` / `✓ 首次启动引导` / `✓ 数据源` / `✓ 本地优先` | **整列删除**。这一列是自我背书（6 个对勾），不承载任何门槛信息，且「✓ 支持」对所有行都成立 = 零信息量 |
| 原 h2：`支持的系统和版本` | 删除。一行标签带不需要大标题；`.section-label`「兼容性」内联在标签带首位即可 |

### HTML 结构（替换 `#compat` 内全部内容）

```html
<section class="compat-section" id="compat">
  <div class="container">
    <div class="compat-strip reveal">
      <span class="cs-label">兼容性</span>

      <span class="compat-tag">
        <svg class="solid" viewBox="0 0 24 24" aria-hidden="true"><path d="M16.37 1.43c0 1.14-.42 2.2-1.25 3.18-.87 1.03-1.9 1.63-2.86 1.55-.13-.98.35-2.06 1.16-3.02.83-.99 2.1-1.65 2.95-1.71zM19.7 17.1c-.5 1.15-.74 1.66-1.38 2.67-.9 1.42-2.16 3.19-3.72 3.2-1.39.01-1.75-.9-3.64-.89-1.89.01-2.29.91-3.68.9-1.56-.01-2.75-1.61-3.64-3.02-2.5-3.94-2.76-8.56-1.22-11.02 1.1-1.75 2.83-2.78 4.46-2.78 1.66 0 2.7.91 4.07.91 1.33 0 2.14-.91 4.06-.91 1.45 0 2.99.79 4.08 2.16-3.59 1.97-3 7.09.61 8.78z"/></svg>
        macOS 12.0+
      </span>

      <span class="compat-tag">
        <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="7" width="10" height="10" rx="2.2"/><path d="M10 7V4.2M14 7V4.2M10 20v-2.8M14 20v-2.8M7 10H4.2M7 14H4.2M20 10h-2.8M20 14h-2.8"/></svg>
        Apple Silicon &amp; Intel
      </span>

      <span class="compat-tag">
        <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="5" width="18" height="12" rx="2"/><path d="M2 19h20"/></svg>
        MacBook / iMac（含非刘海）
      </span>

      <span class="compat-tag">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3l7 3v6c0 4.2-2.9 7.6-7 9-4.1-1.4-7-4.8-7-9V6z"/><path d="M9.5 12.2l1.8 1.8 3.4-3.6"/></svg>
        辅助功能权限
      </span>

      <span class="compat-tag">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 4.5a2 2 0 0 1 4 0V6h3.5A1.5 1.5 0 0 1 18 7.5V11h1.5a2 2 0 0 1 0 4H18v3.5A1.5 1.5 0 0 1 16.5 20H13v-1.5a2 2 0 0 0-4 0V20H7.5A1.5 1.5 0 0 1 6 18.5V15H4.5a2 2 0 0 1 0-4H6V7.5A1.5 1.5 0 0 1 7.5 6H9z"/></svg>
        WPS Comate 1.6.17+
      </span>
    </div>
  </div>
</section>
```

### CSS

```css
.compat-section { padding: 0 0 112px; }            /* top 0 → 读作 #tech 的规格脚注 */
.compat-strip { display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 12px 14px; }
.compat-strip .cs-label { font-size: 13px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--accent); margin-right: 8px; }
.compat-tag { display: inline-flex; align-items: center; gap: 8px; padding: 9px 16px; border-radius: 999px; font-size: 13px; line-height: 1.2; color: var(--text-secondary); background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); white-space: nowrap; }
.compat-tag svg { width: 15px; height: 15px; flex: none; fill: none; stroke: currentColor; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round; opacity: 0.85; }
.compat-tag svg.solid { fill: currentColor; stroke: none; }
```

**宽度预算**：1080px 容器内容宽 1032px。5 个标签实测约 855px + 4×14px gap + 前导 label 约 90px ≈ **1000px ≤ 1032px** → 桌面**恰好一行**，余量约 30px（标签文案再长一点会换行，`flex-wrap` 兜底，换行后居中、不溢出）。≤900px 视口自动折成 2 行。

**`.compat-table` 规则全部保留**（`#appstats` 的今日明细表复用），只删 `#compat` 里的 `<table>` HTML。

---

## 5. 排版规范：间距刻度与区块节奏

### 5.1 间距刻度（本规范引用的所有数值都落在这个刻度上）

| token | 值 | 用途 |
| --- | --- | --- |
| s1 | 4px | 行内微调 |
| s2 | 8px | 图标与文字 |
| s3 | 12px | 紧凑行距、标签 gap |
| s4 | 16px | 卡片内小间距 |
| s5 | 20px | 卡片网格 gap |
| s6 | 28px | 主卡片网格 gap |
| s7 | 40px | 卡片内边距 |
| s8 | 56px | 区块内块间距 |
| s9 | 64px | 区块标题 → 内容 |
| s10 | 112px | 区块上下 padding |

### 5.2 区块节奏：三档（这是本次「不拥挤」的核心）

| 档 | 区块（`padding`） | 相邻间距 | 判据 |
| --- | --- | --- | --- |
| **A · 强分隔 112/112** | `#features` `#lights` `#tech` `#versions` `#powered` `#wish` | **224px** | 每次都是**主题切换**（能力 → 状态语义 → 规格 → 数据 → 生态 → 互动），需要最大留白把上一话题「关掉」 |
| **B · 过渡带** | `hero` 168/96、`mockup-section` 72/128、`footer` 64/64 | hero→mockup **168px**，mockup→features **240px** | `mockup` 是 hero 的实物延续 → 上距收紧到 72（+hero 96 = 168）；它是「看得到的产品」到「读得到的功能」的桥 → 下距放大到 128（+features 112 = 240），让 features 的开场更从容 |
| **C · 紧凑衔接** | `#compat` **0**/112、`#appstats` 96/112 | tech→compat **112px**，versions→appstats **208px** | `#compat` 是 tech 的规格脚注 → **top padding 归零**，读作同一话题的尾注；`#appstats` 与 `#versions` 同属「数据」语境 → top 从 112 收到 96 |

> **对比现状**：现在 12 个 section 全是 `80px 0`，相邻间距一律 160px —— 这就是「节奏平、信息流密」的根源：**所有边界一样重，读者找不到话题切换点**。三档节奏把 160px 的单一间距拆成 112 / 168 / 208 / 224 / 240 五种，视觉上自然分段。

### 5.3 间距改动总表

| 位置 | 现状 | 改为 |
| --- | --- | --- |
| 区块 padding（标准 A 档） | `80px 0` | `112px 0` |
| `hero` | `160px 0 80px` | `168px 0 96px` |
| `mockup-section` | `60px 0 100px` | `72px 0 128px` |
| `compat-section` | `80px 0` | `0 0 112px` |
| `appstats-section` | `80px 0` | `96px 0 112px` |
| `footer` | `48px 0` | `64px 0` |
| **区块标题 → 首个内容**（网格 / 列表 `margin-top`） | 40~48px | **64px** |
| `.section-label` `margin-bottom` | 12px | **20px** |
| 副标题 `margin-top`（`h2` 后） | 16px | **20px** |
| `.hero h1` `margin-bottom` | 24px | 32px |
| `.hero .subtitle` `margin-bottom` | 40px | **56px** |
| `.hero-lights` `gap` / `margin-bottom` | 40px / 48px | **48px / 64px** |
| `.hero-light` `gap` | 10px | 12px |
| `.features-grid` `gap` | 20px | **28px** |
| `.tech-grid` `gap` | 16px | **20px** |
| `.lights-showcase` `gap` / `margin-top` | 60px / 48px | **72px / 64px** |
| `.light-item` `gap` | 16px | 20px |
| `.appstats-kpi` `gap` / `margin-top` | 16px / 40px | **20px / 64px** |
| `.appstats-block` `margin-top` | 40px | **56px** |
| `.appstats-versions` `gap` | 14px | **20px** |
| `.av-row` `gap` | 12px | 16px |
| `.feature-card` padding | `36px 28px` | **`40px 32px`** |
| `.feature-icon` size / `margin-bottom` | 48px / 20px | **52px / 24px** |
| `.tech-card` padding | `24px 20px` | **`28px 24px`** |
| `.arch-detail` padding / `margin-top` | `32px 28px` / 40px | **`40px 36px` / 48px** |
| `.arch-detail li` `margin-bottom` | 4px | **12px** |
| `.version-list` `margin-top` | 40px | **64px** |
| `.version-item` padding / `margin-bottom` | `28px 24px` / 16px | **`32px 28px` / 20px** |
| `.version-item .vi-head` `margin-bottom` | 12px | 16px |
| `.vc-group` `margin-bottom` | 10px | **16px** |
| `.appstats-card` padding | `24px 22px` | **`28px 26px`** |
| `.appstats-block-title` `margin-bottom` | 16px | **24px** |
| `.powered-card` padding / `margin-top` | `40px 32px` / 40px | **`48px 44px` / 56px** |
| powered 总结句 `margin-top` | 32px | **48px** |
| `.wish-form` `margin-top` / `gap` | 40px / 10px | **64px / 14px** |
| `.wish-barrage` `margin-top` | 32px | **48px** |
| `.desktop-hint` `margin-top` | 20px | 28px |

### 5.4 行宽（measure）—— 长文本区块最受益

| 位置 | 现状 | 改为 | 理由 |
| --- | --- | --- | --- |
| 区块副标题 | `max-width: 520px` | **560px** | 16px 下 ≈ 34 字/行，中文阅读最佳区间 |
| `.version-list` | `max-width: 640px` | **720px** | 更新日志是唯一的长文本列表，640px 会频繁折行成 3~4 行短句 |
| `.powered-card p` | `max-width: 560px` | **600px** | 同上 |
| `.light-item p` | `max-width: 180px` | **200px** | 字号提到 14px 后需要更宽才不会挤成 3 行 |
| `.release-body` | `max-width: 480px` | **520px** | 与 `.version-list` 拉齐观感 |
| `.arch-detail` | `max-width: 720px` | 不变 | 已合适 |

### 5.5 字号 / 行高

| 用途 | 现状 | 改为 |
| --- | --- | --- |
| `body` 基线 `line-height` | 1.6 | **1.7** |
| 卡片正文 `.feature-card p` | 14px / 1.65 | **15px / 1.75** |
| `.powered-card p` | 14px / 1.7 | **15px / 1.8** |
| 区块副标题（内联 15px） | 15px | **16px / 1.7** |
| hero 副标题 | `clamp(17px,2.4vw,21px)` / 1.7 | 同尺寸 / **1.8** |
| 次要说明 `.tech-note` `.vi-date` `.av-count` | 12px | **13px** |
| 微型 label `.tech-label` `.k-label` | 11px | **12px** |
| `.arch-detail` | 13px / 1.9 | **14px / 2.0** |
| 更新日志 `.vi-changes` `.vc-list li` | 13px / 1.8 | **14px / 1.9** |
| `.vc-list li` 行间距 | 0 | **`margin-bottom: 6px`** |
| `.feature-card h3` | 18px | **19px** |
| `.light-item h4` / `p` | 16px / 13px | **17px / 14px** |
| `.desktop-hint` | 13px | 14px |
| `footer p` | 13px | **14px**，行距 `8px → 10px` |
| `h2` | `clamp(28px,4vw,40px)` | **尺寸不变**（上限已足够），仅补 `line-height: 1.15` |
| `.section-label` | 13px / `letter-spacing:.1em` | 13px / **`.12em`**（字距稍松，小字更透气） |

> **注意**：`.feature-card h3` 从 18 → 19px 是**唯一一处字号放大**，因为卡片正文放大到 15px 后，18px 标题的相对层级被削弱。其余字号只调行高与次要说明，不放大主体。

---

## 6. 可执行 CSS（覆盖到 index.html `<style>`）

> 以下按「原规则整行替换」给出，不新增选择器层级、不引入 `!important`。

### 6.1 区块 padding 与标题块

```css
.hero { padding: 168px 0 96px; }
.mockup-section { padding: 72px 0 128px; }
.features { padding: 112px 0; }
.lights-section { padding: 112px 0; }
.tech-section { padding: 112px 0; }
.compat-section { padding: 0 0 112px; }
.version-section { padding: 112px 0; }
.appstats-section { padding: 96px 0 112px; }
.powered-section { padding: 112px 0; }
.wish-section { padding: 112px 0 128px; }
footer { padding: 64px 0; }
/* 删除：.how-section 及其下 .steps / .steps::before / .step / .step-num / .step-content h3 / .step-content p 共 7 条 */

.section-label { font-size: 13px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--accent); margin-bottom: 20px; }
.hero h1 { font-size: clamp(42px,7vw,72px); font-weight: 800; line-height: 1.08; letter-spacing: -0.04em; margin-bottom: 32px; }
.hero .subtitle { font-size: clamp(17px,2.4vw,21px); color: var(--text-secondary); max-width: 640px; margin: 0 auto 56px; line-height: 1.8; }
.hero-lights { display: flex; justify-content: center; gap: 48px; margin-bottom: 64px; }
.hero-light { display: flex; flex-direction: column; align-items: center; gap: 12px; min-width: 60px; }
.desktop-hint { margin: 28px auto 0; text-align: center; font-size: 14px; color: var(--text-dim); }
.release-body { margin-top: 14px; padding: 24px 28px; background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); border-radius: 16px; font-size: 13px; color: var(--text-secondary); line-height: 1.9; text-align: left; max-width: 520px; margin-left: auto; margin-right: auto; }
```

### 6.2 features

```css
.features-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 28px; margin-top: 64px; }
.feature-card { background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); border-radius: var(--radius); padding: 40px 32px; transition: all 0.3s cubic-bezier(0.22,1,0.36,1); position: relative; overflow: hidden; }
.feature-icon { width: 52px; height: 52px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 22px; margin-bottom: 24px; }
.feature-card h3 { font-size: 19px; font-weight: 700; margin-bottom: 14px; }
.feature-card p { font-size: 15px; color: var(--text-secondary); line-height: 1.75; }
```
> **HTML 同步改动**：`<div class="features-grid" style="margin-top:48px;">` 的 inline `margin-top` **移除**（改由 CSS 的 `margin-top: 64px` 统一控制，避免双份来源）。

### 6.3 lights

```css
.lights-showcase { display: flex; justify-content: center; gap: 72px; margin-top: 64px; flex-wrap: wrap; }
.light-item { display: flex; flex-direction: column; align-items: center; gap: 20px; }
.light-item h4 { font-size: 17px; font-weight: 600; }
.light-item p { font-size: 14px; color: var(--text-secondary); line-height: 1.75; text-align: center; max-width: 200px; }
```

### 6.4 tech

```css
.tech-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-top: 64px; }
.tech-card { background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); border-radius: 14px; padding: 28px 24px; text-align: center; }
.tech-card .tech-label { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-dim); margin-bottom: 10px; }
.tech-card .tech-note { font-size: 13px; color: var(--text-secondary); line-height: 1.7; margin-top: 8px; }
.arch-detail { max-width: 720px; margin: 48px auto 0; background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); border-radius: var(--radius); padding: 40px 36px; font-size: 14px; line-height: 2; color: var(--text-secondary); text-align: left; }
.arch-detail .arch-title { font-size: 16px; font-weight: 700; color: var(--text); margin-bottom: 20px; }
.arch-detail ul { padding-left: 20px; }
.arch-detail li { margin-bottom: 12px; }
.arch-detail li:last-child { margin-bottom: 0; }
```

### 6.5 compat

见 §4（`.compat-section` + `.compat-strip` + `.cs-label` + `.compat-tag`）。

### 6.6 versions

```css
.version-list { margin-top: 64px; max-width: 720px; margin-left: auto; margin-right: auto; }
.version-item { background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); border-radius: 16px; padding: 32px 28px; margin-bottom: 20px; }
.version-item .vi-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.version-item .vi-date { font-size: 13px; color: var(--text-dim); }
.version-item .vi-changes { font-size: 14px; color: var(--text-secondary); line-height: 1.9; margin-top: 18px; }
.vc-group { margin-bottom: 16px; }
.vc-group:last-child { margin-bottom: 0; }
.vc-list { list-style: none; padding: 8px 0 0; margin: 0; }
.vc-list li { position: relative; padding-left: 14px; font-size: 14px; color: var(--text-secondary); line-height: 1.9; margin-bottom: 6px; }
.vc-list li:last-child { margin-bottom: 0; }
```
> `.vc-list li::before` 的 `top: 10px` 需随行高变化微调为 **`top: 11px`**（保持圆点与首行视觉居中）。

### 6.7 appstats

```css
.appstats-kpi { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-top: 64px; }
.appstats-card { position: relative; background: var(--bg-card); border: 1px solid rgba(255,255,255,0.06); border-radius: 16px; padding: 28px 26px; }
.appstats-card .k-note { font-size: 12px; color: var(--text-dim); margin-top: 8px; }
.appstats-block { margin-top: 56px; }
.appstats-block-title { font-size: 14px; color: var(--text-secondary); margin-bottom: 24px; }
.appstats-chart svg { width: 100%; height: 200px; display: block; }
.appstats-versions { display: flex; flex-direction: column; gap: 20px; }
.av-row { display: flex; align-items: center; gap: 16px; font-size: 14px; }
.av-name { flex: 0 0 96px; color: var(--text-secondary); }
.av-count { flex: 0 0 90px; text-align: right; font-size: 13px; color: var(--text-dim); font-variant-numeric: tabular-nums; }
.appstats-hint { margin-top: 24px; font-size: 13px; color: var(--text-dim); text-align: center; }
```

### 6.8 powered / wish / footer

```css
.powered-card { max-width: 720px; margin: 56px auto 0; background: linear-gradient(135deg, rgba(0,212,170,0.06) 0%, rgba(10,132,255,0.06) 100%); border: 1px solid rgba(255,255,255,0.06); border-radius: var(--radius); padding: 48px 44px; }
.powered-card h3 { font-size: 20px; font-weight: 700; margin-bottom: 16px; }
.powered-card p { font-size: 15px; color: var(--text-secondary); line-height: 1.8; max-width: 600px; margin: 0 auto; }

.wish-form { max-width: 560px; margin: 64px auto 0; display: flex; flex-direction: column; gap: 14px; }
.wish-hint { font-size: 12px; color: var(--text-dim); text-align: center; min-height: 20px; }
footer p { font-size: 14px; color: var(--text-dim); line-height: 1.8; }
```
> `.wish-row input` / `.wish-row textarea` 的 `padding: 10px 14px → 12px 16px`、`font-size: 14px → 15px`；`.wish-barrage { margin-top: 48px }`。
> powered 的 3 张卡复用 `.features-grid`（已由 §6.2 得到 `gap:28px` / `margin-top:64px`），其 HTML inline `style="margin-top:40px;text-align:left;"` 的 `margin-top` 改为 `64px`（保留 `text-align:left`）。
> powered 总结句：inline `margin-top:32px;font-size:14px;` → `margin-top:48px;font-size:15px;line-height:1.8`。

---

## 7. 移动端（并入既有 `@media (max-width:768px)` 块，不新开断点）

桌面留白放大后，移动端不能等比放大（会变成滚动灾难），按「桌面值 × 0.65」收敛：

```css
@media (max-width: 768px) {
  .hero { padding: 128px 0 72px; }
  .mockup-section { padding: 56px 0 88px; }
  .features, .lights-section, .tech-section, .version-section, .powered-section, .wish-section { padding: 72px 0; }
  .compat-section { padding: 0 0 72px; }
  .appstats-section { padding: 64px 0 72px; }
  footer { padding: 48px 0; }

  .section-label { margin-bottom: 14px; }
  .hero h1 { margin-bottom: 24px; }
  .hero .subtitle { margin-bottom: 40px; }
  .hero-lights { gap: 24px; margin-bottom: 44px; }

  .features-grid { gap: 20px; margin-top: 44px; }
  .feature-card { padding: 28px 24px; }
  .feature-icon { width: 46px; height: 46px; margin-bottom: 18px; }

  .lights-showcase { gap: 32px; margin-top: 44px; }
  .light-item { gap: 16px; }
  .light-item p { font-size: 13px; max-width: 160px; }

  .tech-grid { gap: 14px; margin-top: 44px; }
  .tech-card { padding: 22px 18px; }
  .arch-detail { margin-top: 32px; padding: 28px 22px; font-size: 13px; line-height: 1.9; }
  .arch-detail li { margin-bottom: 10px; }

  /* compat 标签带：label 独占一行，标签居中换行 */
  .compat-strip { gap: 10px 12px; }
  .compat-strip .cs-label { flex: 1 1 100%; text-align: center; margin: 0 0 2px; }
  .compat-tag { padding: 8px 14px; font-size: 12px; }

  .version-list { margin-top: 44px; }
  .version-item { padding: 24px 20px; margin-bottom: 14px; }

  .appstats-kpi { grid-template-columns: repeat(2, 1fr); gap: 12px; margin-top: 44px; }
  .appstats-block { margin-top: 40px; }
  .appstats-block-title { margin-bottom: 16px; }
  .appstats-versions { gap: 16px; }

  .powered-card { margin-top: 40px; padding: 32px 24px; }
  .wish-form { margin-top: 44px; }
  .wish-barrage { margin-top: 36px; }
}
```
**必须删除的两条既有移动端规则**：`.steps::before { left: 23px; }`（随 how-section 一起删）；`.lights-showcase { gap: 32px; }`（已被上面合并保留）。
**保留不动**：`.compat-table th, .compat-table td { padding: 12px 14px; }`（服务于 `#appstats` 明细表）。

移动端复核点：
- 375px：`.feature-card` 内容宽 `327 − 48 = 279px`，15px 正文 ≈ 18 字/行 → 卡文 2 行内成立；
- `.compat-strip` 5 个标签折成 3 行（label 独占首行），总高 ≈ 130px，可接受；
- 无新增横向滚动条（标签 `white-space:nowrap` + 容器 `flex-wrap`）。

---

## 8. 与既有代码的衔接（改动点清单，行号以当前 `index.html` 1308 行为准）

| 位置 | 动作 |
| --- | --- |
| CSS 41 / 45 / 46 / 47 | `.hero` padding、`.hero .subtitle`、`.hero-lights`、`.hero-light` 按 §6.1 替换 |
| CSS 43 | `.hero h1` `margin-bottom` 24 → 32px |
| CSS 28 | `.section-label` `letter-spacing` → `.12em`、`margin-bottom` → 20px |
| CSS 72 | `.release-body` `max-width` 480 → 520px |
| CSS 115 / 175 | `.mockup-section` padding、`.desktop-hint` 字号与 `margin-top` |
| CSS 199–213 | `.features` / `.features-grid` / `.feature-card` / `.feature-icon` / `.feature-card h3` / `.feature-card p` 按 §6.2 替换 |
| CSS 214–224 | `.lights-section` / `.lights-showcase` / `.light-item` / `.light-item h4` / `.light-item p` 按 §6.3 替换 |
| **CSS 225–231** | **`.how-section` / `.steps` / `.steps::before` / `.step` / `.step-num` / `.step-content h3` / `.step-content p` 共 7 条整块删除** |
| CSS 232–242 | `.tech-section` / `.tech-grid` / `.tech-card` / `.tech-label` / `.tech-note` / `.arch-detail` / `.arch-title` / `ul` / `li` 按 §6.4 替换 |
| CSS 243–249 | `.compat-section` 改为 `padding: 0 0 112px`；**`.compat-table` 及其 5 条子规则全部保留**（`#appstats` 复用）；新增 `.compat-strip` / `.cs-label` / `.compat-tag` 三组规则 |
| CSS 250–268 | `.version-section` / `.version-list` / `.version-item` / `.vi-date` / `.vi-changes` / `.vc-group` / `.vc-list` / `.vc-list li` 按 §6.6 替换；`.vc-list li::before` 的 `top` 10 → 11px |
| CSS 271–274 | `.powered-section` padding、`.powered-card` padding/`margin-top`、`.powered-card h3`、`.powered-card p` 按 §6.8 替换 |
| CSS 279–280 | `footer` padding、`footer p` 字号行高 |
| CSS 284–292 | `.wish-section` padding、`.wish-form`、`.wish-hint`；`.wish-row input/textarea` padding 与字号；`.wish-barrage` `margin-top` |
| CSS 326–356 | `.appstats-section` / `.appstats-kpi` / `.appstats-card` / `.k-note` / `.appstats-block` / `.appstats-block-title` / `.appstats-chart svg` / `.appstats-versions` / `.av-row` / `.av-name` / `.av-count` / `.appstats-hint` 按 §6.7 替换 |
| CSS 358–385（`@media`） | 按 §7 合并/替换；**删除 `.steps::before` 一条** |
| HTML 402 | hero 副标题按 §2.1 替换（保留 `<br/>`） |
| HTML 462 | `.desktop-hint` 文案按 §2.2 替换 |
| HTML 539 | features 区块标题块**不变** |
| **HTML 540** | `features-grid` 的 inline `style="margin-top:48px;"` **删除**（改由 CSS 控制） |
| HTML 541–546 | 6 张功能卡文案按 §2.3 替换（卡片数量、图标、`.feature-icon` 配色类**全部不变**） |
| HTML 549–557 | `lights-showcase` 4 项 `<h4>` 去 emoji、`<p>` 按 §2.4 替换 |
| **HTML 561–570** | **`<section class="how-section">` 整块删除（10 行）** |
| HTML 573–574 | tech 副标题按 §2.6 替换；8 张 `tech-card` 的 note 按 §2.6 替换（label/value 全不变） |
| HTML 577–583 | `.arch-detail` 的 `.arch-title` 去 emoji；5 条 `<li>` 按 §2.6 替换（`<strong>` / `<code>` 结构保留） |
| **HTML 598–611** | **`#compat` 内的 `<h2>` + `<table>` 整体替换为 §4 的 `.compat-strip`（section 与 `id="compat"` 保留）** |
| HTML 616 | versions h2 不变 |
| HTML 624 | appstats 副标题不变 |
| HTML 627 / 631 / 635 | 3 个 `.appstats-block-title` 文案按 §2.9 替换 |
| HTML 644–646 | powered 副标题、3 张卡标题/场景/「它做的」按 §2.10 替换 |
| HTML 648 | powered 总结句按 §2.10 替换（`margin-top:32px` → `48px`，`font-size:14px` → `15px`） |
| HTML 653 / 655 | `.powered-card` 正文与免责声明按 §2.10 替换 |
| HTML 661–664 | wish 副标题、两个 placeholder 按 §2.11 替换 |
| HTML 676–678 | footer 第 2 行按 §2.12 替换 |
| JS | **不动**。更新日志渲染、下载计数、appstats 渲染、`.reveal` 观察器、`versions.json` 契约均无改动 |
| 全站 | 无新增外部请求；无新增颜色；无新增字体 |

---

## 9. Acceptance Contract

**文案**
- [ ] 全站搜索 `v1.3.0 新增` 零命中；功能卡正文不再出现版本溯源
- [ ] 全站搜索 `柔和而有存在感` / `安静守候` / `轻量无冗余` / `不必从零搭建` / `定当持续更新为报` / `一目了然` / `紧急提醒` 零命中
- [ ] 6 张功能卡数量、标题、图标、`.feature-icon` 配色类**与现状完全一致**，仅正文措辞变化
- [ ] 卡片 1「实时状态灯」正文**不再枚举 4 种颜色**（颜色枚举只在 `#lights` 出现一次）；`#lights` 的 `<h4>` 内 emoji 全部消失
- [ ] `#lights` 4 条仍保留 `15 分钟` 这个数字；`.arch-detail` 5 条仍保留 `2s` / `30s` / `5 轮` / `120fps` / `wps_sid` 这些具体值
- [ ] powered 免责声明仍完整表达 4 个事实：独立应用 / 非 WPS 官方 / 社区开发者 / 基于 Comate 开放能力
- [ ] 每张功能卡正文 ≤ 2 行（1080px 视口）；每个区块副标题 ≤ 2 行
- [ ] 全站总字数较改前下降 18%~25%（更新日志不计）

**结构**
- [ ] `index.html` 中不存在 `<section class="how-section">`；不存在 `.steps` / `.step` / `.step-num` / `.step-content` 任何引用（HTML 与 CSS 双向确认）
- [ ] 页面区块数 13 → **12**；区块顺序为 nav → hero → mockup → features → lights → tech → compat → versions → appstats → powered → wish → footer
- [ ] 导航 8 个锚点 + 页脚链接**全部有效**：`#features` `#lights` `#tech` `#compat` `#versions` `#appstats` `#powered` `#wishwall` `#download` 逐个点击均正确滚动
- [ ] `#compat` section 与 `id="compat"` **仍然存在**，不与固定导航重叠
- [ ] `#compat` 内不再有 `<table>` 与 `<h2>`；`.compat-table` 的 5 条 CSS 规则**仍存在**（`#appstats` 今日明细表正常渲染）
- [ ] compat 标签带含 5 个标签，覆盖：OS 版本、CPU 架构、设备机型、辅助功能权限、WPS Comate 版本；**原「状态」列（✓ 支持 等 6 个对勾）全部消失**
- [ ] 新增的 5 个图标全部为手写内联 SVG，无 emoji、无图标库、无外部图片

**排版**
- [ ] 12 个区块的 `padding` 呈**三档**：112/112（6 个 A 档）、`#compat` top = **0**、`#appstats` top = **96**、hero/mockup/footer 为过渡值 —— 不再出现「全部 80px」
- [ ] 所有「区块标题 → 首个内容」的间距统一为 **64px**（含 `.features-grid` 的 inline `margin-top` 已移除）
- [ ] `.features-grid` `gap: 28px`、`.tech-grid` `gap: 20px`、`.appstats-kpi` `gap: 20px`
- [ ] `.feature-card` padding `40px 32px`、`.tech-card` `28px 24px`、`.arch-detail` `40px 36px`、`.powered-card` `48px 44px`、`.appstats-card` `28px 26px`、`.version-item` `32px 28px`
- [ ] `body` `line-height: 1.7`；`.feature-card p` 为 `15px / 1.75`；`.arch-detail` 为 `14px / 2.0`；更新日志正文为 `14px / 1.9`
- [ ] `.version-list` `max-width: 720px`、副标题 `max-width: 560px`、`.powered-card p` `max-width: 600px`
- [ ] `.arch-detail li` `margin-bottom: 12px`；`.vc-group` `margin-bottom: 16px` —— 密集列表不再是「贴着排」
- [ ] 未新增任何分隔线、背景分区、装饰图形；页面仍无 section 级边框

**工程约束**
- [ ] 未改动 `:root` 任何 token；未新增颜色值（新规则只用既有变量与 `rgba(255,255,255,0.03/0.06/0.08/0.1)`）
- [ ] 源码中不出现 `oklch(` / `color-mix(` / `@layer`
- [ ] 无任何新增外部请求（Network 面板无变化）；无新增字体族
- [ ] 移动端规则全部写在既有 `@media (max-width:768px)` 块内，**未新增断点**；`.steps::before` 的移动端规则已删除
- [ ] 375px / 768px / 1080px 三档宽度下**均无横向滚动条**（compat 标签带 `flex-wrap` 生效、`#appstats` 明细表仅自身横向滚动）
- [ ] `.reveal` 观察器参数与 JS 均未改动；`#compat` 的 `.compat-strip` 保留 `.reveal` 类并可正常淡入
- [ ] `versions.json` 数据契约、下载计数逻辑、appstats 渲染逻辑零改动
- [ ] 未改动 hero 下载区 `#download` 内部任何结构、文案与样式

---

## 10. 1.5 修订：区块重排与信息精简（本轮变更）

> 本节优先级**高于上文冲突处**：§2.6 / §2.7 / §2.8 / §4 / 硬约束 / 否决项中与本轮冲突的表述，以本节为准（已就地标注作废的除外）。

### 10.1 变更清单

| # | 变更 | 落点 |
| --- | --- | --- |
| 1 | 更新日志文案简化：**41 条 → 30 条**，去掉构建脚本回退 / Cookie 校验 / DB 异步队列等内部细节，统一用户视角短句（单条最长 38 字） | `ComateHUD/versions.json` |
| 2 | hero 下载区下方的 Release Notes 折叠改为**锚点行**：版本号与更新日期同行、日期加重，整行点击跳 `#versions`，首屏不再展开正文 | `#release-line`（替换 `#release-toggle` / `#release-body` / `#rn-summary`） |
| 3 | 下载区元信息行去掉重复的日期标签，日期只出现在 ② 的锚点行 | `.dl-tags`（删除 `#dl-date` / `#dl-date-text`） |
| 4 | 「技术栈」改名「**如何实现**」，补背景：作为第三方应用不修改 / 不注入 WPS Comate 本体，只读本地 SQLite + 官方 `wpscomate://` Deeplink | `#tech` 的 `.section-label` / `h2` / 副标题 |
| 5 | 「兼容性」不再独立成区块：`#compat` section 删除，标签带并入 `#tech`（`.arch-detail` 之后），导航去掉「兼容性」 | `#tech` / `nav` |
| 6 | `#versions` 移到 `#wishwall` **正上方**（读作「反馈了就会有更新」），导航同步；收起态条目行高压缩，日期改用 accent 加重 | `#versions` / `nav` |

**区块顺序（DOM = 导航顺序）**：`features → lights → tech → appstats → powered → versions → wishwall`，另有 `#download`（hero 内）。

### 10.2 文案

| 位置 | 原文 | 现文案 |
| --- | --- | --- |
| `#tech` label | `技术栈` | `如何实现` |
| `#tech` h2 | `纯原生，零依赖` | `不侵入 Comate 的旁路实现` |
| `#tech` 副标题 | `100% Swift + SwiftUI，无 Electron、无 WebView、无第三方框架。` | `作为第三方应用，Comate HUD 不修改、不注入 WPS Comate 本体：只读它写在本地 SQLite 的会话记录，配合官方 <code>wpscomate://</code> Deeplink 完成跳转。100% Swift + SwiftUI，无 Electron、无 WebView、无第三方框架。`（`max-width` 520 → 620px，`<code>` 用 `.tech-section .reveal code` 行内样式） |
| 导航 | `技术栈` + `兼容性` 两项 | `如何实现` 一项 |
| 版本记录行 | `▸ v1.4.1 Release Notes`（可展开） | `最新版本 v1.4.1 · 2026-09-24  查看更新日志 ›`（不可展开，锚点） |

### 10.3 净增 CSS

```css
/* 下载区下方的版本记录：版本号与更新日期同行，整行点击锚点跳到更新日志 */
.release-line { display: inline-flex; align-items: center; justify-content: center; gap: 8px; margin-top: 20px; font-size: 13px; line-height: 1.2; text-decoration: none; color: var(--text-dim); transition: color 0.2s; }
.release-line[hidden] { display: none; }
.release-line:hover { color: var(--text-secondary); }
.release-line .rl-ver { font-size: 14px; font-weight: 700; color: var(--text); }
.release-line .rl-sep { color: rgba(255,255,255,0.22); }
.release-line .rl-date { font-weight: 600; color: var(--accent); font-variant-numeric: tabular-nums; }
.release-line .rl-more { display: inline-flex; align-items: center; gap: 3px; margin-left: 2px; }
.release-line .rl-more svg { transition: transform 0.2s; }
.release-line:hover .rl-more svg { transform: translateX(2px); }

/* 兼容性标签带并入 #tech，作为规格脚注 */
.compat-strip { /* …原规则不动… */ margin-top: 48px; }

/* 更新日志条目：收起态紧凑、日期加重 */
.version-item { padding: 20px 28px; margin-bottom: 14px; }          /* 原 32px / 20px */
.version-item[open] { padding: 30px 28px; margin-bottom: 20px; }
.version-item[open] .vi-head { margin-bottom: 16px; }              /* 收起态不给段间距 */
.version-item .vi-head { gap: 4px 12px; flex-wrap: wrap; }
.version-item .vi-meta { display: inline-flex; align-items: center; gap: 8px; font-size: 13px; line-height: 1.2; }
.version-item .vi-date { font-weight: 600; color: var(--accent); font-variant-numeric: tabular-nums; }   /* 原 13px / var(--text-dim) */
.version-item .vi-count { color: var(--text-dim); }
.version-item summary .vi-meta::after { content: '▾'; font-size: 11px; color: var(--text-secondary); }   /* 收起态是主状态，箭头提亮到 secondary */
.version-item[open] summary .vi-meta::after { content: '▴'; }
```

收起态条目实测高度：**102px → 62px**（padding 32→20 上下各 −12，`vi-head` 段间距 −16）。

### 10.4 删除的规则（不留死代码）

| 选择器 | 条数 | 说明 |
| --- | --- | --- |
| `.release-toggle` | 4 | 折叠交互整体移除 |
| `.release-body`（含 `.rv` / `.cat`×4 / `.rn-*`×4） | 10 | 首屏不再渲染更新日志正文 |
| `.compat-section` | 2 | 桌面 + 移动；section 已删 |
| **保留** `.compat-table` | 10 | `#appstats` 今日明细表复用（`table class="compat-table stats-table"`），**不得删除** |

### 10.5 移动端（`@media (max-width:768px)` 块内）

```css
.compat-strip { margin-top: 32px; gap: 10px 12px; }
.version-item { padding: 17px 20px; margin-bottom: 12px; }
.version-item[open] { padding: 24px 20px; }
.version-item .vi-head { gap: 4px 10px; }   /* 改回单行：版本号与日期同行，不再强制竖排 */
```

`.release-line` 无需移动端规则（`inline-flex` + 容器居中，窄屏自然换行）。

### 10.6 JS 契约

- `#release-line` 初始带 `hidden`（与 `#dl-size` 同一约定，数据到达前不出现 `v—` 占位符），`fetch` 成功分支写入 `#rl-ver` / `#rl-date` 后 `rl.hidden = false`；`catch` 分支不做处理（保持隐藏，hero 的 MAC 按钮已退化为「前往更新日志」）。
- 版本条目 summary 结构改为 `vi-ver` + `vi-meta(vi-date + vi-count)`，箭头由 `.vi-meta::after` 承担；`typeLabels` / `typeColors` 与 `#version-list` 渲染逻辑不变。
- `versions[0]` 仍默认 `open`（首条展开，其余收起）。

### 10.7 应用统计改版：换位 · 口语化 · 一键分享

#### 10.7.1 区块换位（与「能力提供」互换）

| 项 | 改前 | 改后 |
| --- | --- | --- |
| DOM 顺序 | features → lights → tech → **appstats → powered** → versions → wishwall | features → lights → tech → **powered → appstats** → versions → wishwall |
| 导航顺序 | … 如何实现 · **应用统计 · 能力提供** · 更新日志 … | … 如何实现 · **能力提供 · 应用统计** · 更新日志 … |

`#appstats` 仍是 `.appstats-section`（padding `96px 0 112px`），前面由 `#tech` 换成 `#powered`（`112px 0`），间距无需调整。`#appstats` 与 `#nav-appstats` 的 `hidden` 解隐逻辑（`loadActivity()` 里 `removeAttribute`）与顺序无关，未改动。

#### 10.7.2 文案口语化

| 位置 | 原文 | 现文案 |
| --- | --- | --- |
| h2 | `谁在用 Comate HUD` | `看灯的人，不止你一个` |
| 副标题 | `安装设备每天上报一次活跃，按用户去重统计。`（静态） | 删除，改为动态人数句 `#appstats-people`（见 10.7.3） |
| 趋势块标题 | `近 30 日活跃趋势` | `最近 30 天，每天有多少人来亮灯` |
| 版本分布块标题 | `版本分布` | `大家都在用哪一版` |
| KPI note | `… · 按用户去重` / `滚动 7 天` / `滚动 30 天` / `有记录以来` | `… · 按人头算` / `最近一周 · 按人头算` / `最近一个月 · 按人头算` / `从发布到现在` |
| 版本分布空态 | `近 30 日还没有活跃数据` | `最近 30 天还没有人来亮灯` |
| 明细空态 | `今天还没有设备上报` | `今天还没有人来亮灯` |
| 明细块标题 | `今日活跃明细` | 不变（owner 专用调试视图，保持功能性） |

KPI 的 4 个 label（`今日活跃` / `近 7 日活跃` / `近 30 日活跃` / `累计活跃`）保持功能性不改，避免数字含义被口语化模糊。

#### 10.7.3 人数句 `#appstats-people`

静态占位（`hidden`，避免数据到达前闪现），`renderStatsPeople(rows)` 填内容：

- `累计活跃 > 0`：`已经有 <b>N</b> 位 Mac 用户把它钉在了刘海区——现在，你也是其中之一。`
- `累计活跃 = 0`：`统计刚上线，你很可能就是第一批——来当第 1 位。`
- 请求失败（`statsError`）：不填、保持 `hidden`，由 `#appstats-hint` 说明原因

`statsLoading()` 里先清空并 `hidden`，避免重试时残留旧数字。数字用 `createElement` + `textContent` 构造（不拼 HTML）。

```css
.appstats-people { max-width: 560px; margin: 16px auto 0; font-size: 15px; line-height: 1.7; color: var(--text-secondary); }
.appstats-people[hidden] { display: none; }
.appstats-people b { font-size: 22px; font-weight: 800; letter-spacing: -0.02em; color: var(--accent); font-variant-numeric: tabular-nums; vertical-align: -1px; margin: 0 3px; }
```

#### 10.7.4 一键分享 `.appstats-share`

位置：版本分布块之后、`#appstats-today-block` 之前。**刻意不用 `.appstats-block` 类**——`statsShowBlocks()` 会按该类批量 `hidden`，而分享在统计拉不到时依然应该可用。

文案：标题 `好东西，别自己藏着` / 正文 `你隔壁工位那位，大概率也在用 Comate。把链接丢给他，让他也少开几次主窗口。` / 按钮 `一键分享`。

**能力自适应**（无外部依赖、无 SDK）：

| 环境 | 按钮文案 | 点击行为 |
| --- | --- | --- |
| `typeof navigator.share === 'function'` | `一键分享` | `navigator.share({title, text, url})` 调系统分享面板 |
| 无 Web Share | `复制链接分享` | 复制「文案 + 官网链接」到剪贴板 |

- `share()` reject 时：`AbortError` / `NotAllowedError`（用户取消、无用户手势）→ 静默；其余错误 → 退回复制。
- 复制路径：优先 `navigator.clipboard.writeText`（需安全上下文），回退临时 `<textarea>` + `document.execCommand('copy')`。
- 反馈：按钮文案变 `已复制，去发给同事`（失败则 `复制失败，手动复制下方链接`）并加 `.is-copied`（透明底 + accent 描边），同时把链接以 `#appstats-share-url` 摆出来供手选；2.8s 后复原。
- 分享 URL = `location.href` 去掉 `#hash` 与 `?query`。

```css
.appstats-share { margin-top: 56px; text-align: center; }
.appstats-share-title { font-size: 19px; font-weight: 700; }
.appstats-share-text { max-width: 460px; margin: 10px auto 0; font-size: 14px; line-height: 1.75; color: var(--text-secondary); }
.appstats-share-btn { display: inline-flex; align-items: center; gap: 8px; margin-top: 22px; padding: 12px 24px; font-family: inherit; font-size: 14px; font-weight: 600; color: #06140f; background: var(--accent); border: 1px solid var(--accent); border-radius: 999px; cursor: pointer; transition: transform 0.15s, box-shadow 0.2s, background 0.2s, color 0.2s; }
.appstats-share-btn:hover { transform: translateY(-1px); box-shadow: 0 8px 24px var(--accent-glow); }
.appstats-share-btn svg { width: 16px; height: 16px; flex: none; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
.appstats-share-btn.is-copied { color: var(--accent); background: transparent; box-shadow: none; }
.appstats-share-url { margin-top: 14px; font-size: 12px; color: var(--text-dim); word-break: break-all; }
.appstats-share-url[hidden] { display: none; }
```
移动端（`@media (max-width:768px)`）：`.appstats-share { margin-top: 40px; }`。
