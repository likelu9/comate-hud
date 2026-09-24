---
version: "1.2"
style: "minimal-dark-macos"
target: "ComateHUD/index.html：① #appstats 区块（插在 #versions 与 #wishwall 之间）；② hero 内下载区 #download 重构（公共信息行 / MAC·WIN·GitHub 三按钮 / 按钮外体积元信息行 / macOS 安装说明 hover 气泡）"
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
references:
  - "references/stats-mockup.svg"
  - "references/download-section.svg"
release_contract:
  size_source: "versions.json → versions[0].size"
  writer: "ComateNotch/release.sh（发版时用 stat 计算 DMG 字节数并格式化写入）"
  fallback: "size 为 \"-\" / 空 → 官网整条隐藏体积，绝不回落硬编码"
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
            <p class="dl-help-row"><span class="dl-help-k">【首次打开】</span>本应用未使用 Apple 付费开发者证书签名，macOS 会拦截首次启动。任选一种方式放行：</p>
            <p class="dl-help-sub">方式一：右键点击 Comate HUD.app → 选择「打开」→ 在弹窗中再点「打开」</p>
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
- [ ] 气泡内容与用户原话逐字一致：【安装】、【首次打开】、方式一、方式二 + 命令 `xattr -dr com.apple.quarantine /Applications/ComateHUD.app`；命令为等宽字体 + 深色代码块 + 内部横向滚动，**始终一整行**（复制不产生多余换行）
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
