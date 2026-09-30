---
version: "2.0"
stage: "review"
style: "dark-minimal"
scope: "设计规范（token + 原则 + 四个界面：主面板 / 设置窗口 / 刘海形态 / 关于并入设置）"
palette:
  primary: "#00D4AA"
  secondary: "#22E0BB"
  accent: "#FF4D4F"
  background: "#0F0F11"
  surface: "#1F1F1F"
  text: "#F5F5F5"
fonts:
  heading: "SF Pro Rounded 11pt semibold"
  body: "SF Pro Rounded 12pt regular"
surfaces:
  - id: "overview"
    title: "审阅总页 / Token 色板"
  - id: "notch-collapsed"
    title: "刘海收起条"
  - id: "panel-main"
    title: "主 HUD 面板"
  - id: "task-list"
    title: "任务列表区"
  - id: "footer-quota"
    title: "页脚额度区"
  - id: "empty-state"
    title: "空态占位"
  - id: "about"
    title: "关于窗口"
  - id: "settings"
    title: "设置面板"
---

# Comate HUD · 深色 KDesign 设计规范（骨架 v1.0）

> 目标：macOS 14+ 原生（Swift / AppKit）。近黑悬浮面板常驻桌面顶部，读图 ROI 是「一眼读完当前任务状态」。
> 依据：`kd-foundation` v3.0.0（token 唯一事实源）+ `kd-design-language` v1.0.0（决策规则）。
> 本次范围：**只出设计规范骨架与 token 表**，不产出具体界面 HTML。

---

## 0. 命名与阅读约定

| 约定 | 说明 |
|---|---|
| 语义名 | 统一 `域.角色.态` 三段式：`surface.*` / `text.*` / `line.*` / `accent.*` / `status.*` / `radius.*` / `space.*` / `font.*` / `dur.*` / `ease.*` / `shadow.*` / `metrics.*` |
| 实现变量 | 表中括号内为工程既有 CSS 变量名（`docs/designs/references/_css/hud.css`），Swift 侧按同名常量落地 |
| `rgba` 为准 | 含 alpha 的值为**实际实现值**；旁列 `#RRGGBB` 是已按面板底 `#0F0F11` 合成的**不透明等效色**，仅用于对照与色板渲染 |
| 来源列 | `代码` = 工程现有实现值，本次不改；`KD` = 对齐 KD 官方 token；`新增` = 本次新增语义 |
| 单位 | macOS `pt`（@1x 时 1pt = 1px），与 KD 的 px 对等 |

---

## 1. 设计原则

**P1 · 深色 KD = 中性灰阶做层级，饱和色只做语义。**
面板底保持近黑 `surface.panel = #0F0F11`（与物理刘海无缝的收起条再用纯黑 `surface.bar = #000000`）。层级不靠「越上层越亮」的堆色法，而靠 KD 深色灰阶的三档背景 + 两级分隔线。除品牌绿 `#00D4AA` 外，内容区不出现饱和色；红/橙/绿只允许出现在任务状态灯、Logo 四态、更新红点三个语义位。

**P2 · 靠间距与分组建立层级，不靠颜色和装饰。**
层级优先序固定为 **间距 > 字重 > 颜色**：分组间 `space.6 = 6`，列表行间 `space.3 = 3`，面板内边距左右 12 / 顶 8 / 底 12，标题行高 `metrics.header = 18`。判据沿用 KD 原文——「一个视觉元素被移除后信息传达不受影响，它就不应存在」：面板内卡片不再叠背景色与描边，面板自身那 1pt 白 12% 描边已是唯一容器级装饰。

**P3 · 功能色只表语义，同屏饱和色 ≤ 2。**
`status.*` 四态色只允许出现在状态灯、状态文案、状态软底三处，禁止用于图标着色、按钮底色、装饰线。常态下一个视图最多 2 种饱和色（品牌蓝 + 当前状态色）。Logo 四态用色是「用色表状态、而非表品牌」的正面样板，应与列表状态灯**共用同一支色板**，不另开一套。

**P4 · macOS 原生几何优先，KD 刻度为基线，例外必须登记。**
点击目标 ≥ 44pt（左侧图标交互区 44）；视觉元素可小于点击区（状态灯 7pt 圆点、拖拽手柄胶囊 44×3）。当原生几何与 KD 尺度冲突（3 / 6 间距、11pt 字号均不在 KD 刻度上）时，**以原生几何为准并登记为例外**，不做四舍五入去迁就刻度——四舍五入会让面板变胖、刘海条对不齐硬件。

**P5 · 动效克制、可预期、可降级。**
只用透明度与位移，不用缩放弹跳；单次时长 ≤ 400ms，常用 120–250ms。禁用态统一用 KD 的 `opacity: 0.4`，不用灰色替代色。`prefers-reduced-motion` 下所有动画需退化为无动画终态。

---

## 2. Token 表

> 等效 hex 均按面板底 `#0F0F11` 合成；实现请以 rgba 为准。来源列 `代码` = 工程现有实现值，本次不变。

### 2.1 背景层次（3 档主结构 + 派生）

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `surface.panel` | `rgba(15,15,17,1)` | `#0F0F11` | **面板底**：主 HUD 面板、设置窗口、关于窗 | 代码 `--hud-surface-panel` |
| `surface.raised` | `rgba(255,255,255,.06)` | `#1D1D1F` | **悬浮层**：次级控件底、设置导航底、面板内浮起卡片；对标 KD `background-group #1F1F1F` | 新增 `--hud-surface-raised` |
| `line.divider` | `rgba(255,255,255,.08)` | `#232325` | **分隔线**：行分隔、区块分隔（= KD 深色 `line-light` 8%） | 新增 `--hud-line-divider` |
| `surface.bar` | `rgba(0,0,0,1)` | `#000000` | 刘海收起条底（与硬件开孔无缝，不用 `surface.panel`） | 代码 `--hud-surface-bar` |
| `surface.card` | `rgba(255,255,255,.045)` | `#1A1A1C` | 卡面：关于窗图例卡、系统要求块、更新行 | 代码 `--hud-surface-card` |
| `surface.row` | `rgba(255,255,255,.04)` | `#19191B` | 任务行常态底 | 代码 `--hud-surface-row` |
| `surface.row-hover` | `rgba(255,255,255,.10)` | `#272729` | 任务行悬停 | 代码 `--hud-surface-row-hover` |
| `surface.row-pressed` | `rgba(255,255,255,.14)` | `#313133` | 任务行按下 | 新增 `--hud-surface-row-pressed` |
| `surface.hit` | `rgba(255,255,255,.12)` | `#2C2C2E` | 图标按钮悬停命中底 | 代码 `--hud-surface-hit` |
| `surface.track` | `rgba(255,255,255,.10)` | `#272729` | 周期胶囊轨道底 | 代码 `--hud-surface-track` |
| `surface.skeleton` | `rgba(255,255,255,.06)` | `#1D1D1F` | 加载骨架底 | 新增 `--hud-surface-skeleton` |
| `surface.scrim` | `rgba(0,0,0,.48)` | — | 弹窗遮罩 | 新增 `--hud-surface-scrim` |

### 2.2 文字（4 档 + 扩展）

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `text.primary` | `rgba(245,245,245,1)` | `#F5F5F5` | 标题、正文、任务标题（= KD 深色 `text-primary`） | 代码 `--hud-text-primary` |
| `text.secondary` | `rgba(245,245,245,.72)` | `#B5B5B5` | 次文本、面板标题、图例 | 代码 `--hud-text-secondary` |
| `text.tertiary` | `rgba(245,245,245,.55)` | `#8E8E8E` | 图标常态、说明文案 | 代码 `--hud-text-tertiary` |
| `text.disabled` | `rgba(245,245,245,.30)` | `#545454` | 禁用文本（脚注、不可用项）；交互控件禁用改走 `opacity:.4` | 新增 `--hud-text-disabled` |
| `text.quaternary` | `rgba(245,245,245,.46)` | `#797979` | 行内 meta、空态文案（`tertiary` 的行内细分档） | 代码 `--hud-text-quaternary` |
| `text.on-accent` | `rgba(15,15,17,1)` | `#0F0F11` | 品牌绿实底上的**深墨**字（绿为亮色，白字仅 ≈1.9:1） | KD `--hud-text-on-accent` 改值 |
| `surface.chip` | `rgba(255,255,255,.06)` | — | 悬浮模式图标的半透明承托块（hover `.10` / 按下 `.14` / 展开中 `.12`） | 新增（§7.7） |
| `line.chip` | `rgba(255,255,255,.08)` | — | chip 描边 `1px`（hover `.10` / 按下 `.12` / 展开中 `.14`） | 新增（§7.7） |
| `radius.chip` | `10pt` | — | chip 圆角（`36×36`） | 新增（§7.7） |
| `metrics.footer-h` | `34pt` | — | 页脚两行结构总高（`6 + 14 + 4 + 4 + 6`） | 新增（§7.1） |
| `radius.meter` | `2pt` | — | 额度进度条圆角（条高 `4pt`） | 新增（§7.1） |
| `text.strong` | `rgba(245,245,245,.92)` | `#E3E3E3` | 脚注中的加粗关键值 | 代码 `--hud-text-strong` |

### 2.3 描边与焦点

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `line.panel` | `rgba(255,255,255,.12)` | `#292929` | 面板描边 **1pt**（面板唯一容器装饰，不用阴影） | 代码 `--hud-line-panel` |
| `line.card` | `rgba(255,255,255,.07)` | `#1F1F21` | 卡片 / 独立窗口描边 | 代码 `--hud-line-card` |
| `line.divider-strong` | `rgba(255,255,255,.14)` | `#2C2C2E` | 分组间强分隔（= KD 深色 `line-regular` 14%） | 新增 `--hud-line-divider-strong` |
| `line.focus` / `accent.line` | `rgba(0,212,170,1)` | `#00D4AA` | 键盘焦点环 `outline: 2px` + `offset 1px` | 代码 `--hud-accent-line` |
| `line.on-accent` | `rgba(255,255,255,.09)` | — | 绿色实底控件内描边 | 代码（关于窗图标） |

### 2.4 交互主色（KD 品牌蓝，内容区唯一饱和色）

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `accent.normal` | `rgba(0,212,170,1)` | `#00D4AA` | 主按钮底、选中态、进度、品牌语（**唯一品牌/交互主色**） | 用户拍板（原 `#0A6CFF`） |
| `accent.hover` | `rgba(34,224,187,1)` | `#22E0BB` | 悬停 | 用户拍板（原 `#3B89FF`） |
| `accent.pressed` | `rgba(0,169,138,1)` | `#00A98A` | 按下 | 用户拍板（原 `#0557D6`） |
| `accent.disabled` | `rgba(0,212,170,.40)` | `#00D4AA @40%` | 禁用（= KD `--kd-opacity-disabled` 0.4） | KD |
| `accent.soft` | `rgba(0,212,170,.16)` | — | 选中行底、激活态底、软强调 | 原 `rgba(10,108,255,.16)` |
| `accent.on` | `rgba(15,15,17,1)` | `#0F0F11` | 绿底前景（文字/图标）——**必须深墨** | 用户拍板 |
| `accent.track` | `rgba(0,212,170,.22)` | — | 进度条已填充段 | 原 `rgba(10,108,255,.22)` |

> 注：KD 深色主题把 `blue-6` 提亮到 `#1E74FF`；本设计已按用户拍板**改用品牌绿 `#00D4AA` 作为交互主色**（不再使用 KD 蓝），全链路（点击态/焦点态/主按钮）统一取 `#00D4AA` 这一支；绿底一律配深墨字（见 §3.0）。

### 2.5 四态语义色与更新红点

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `status.idle` | `rgba(156,160,170,1)` | `#9CA0AA` | 空闲 / 待办（Logo 态 1 + 状态灯） | 代码 `--hud-status-idle` |
| `status.working` | `rgba(255,201,40,1)` | `#FFC928` | 工作中（Logo 态 3 + 状态灯，可呼吸闪烁） | 代码 `--hud-status-working` |
| `status.waiting` | `rgba(255,98,89,1)` | `#FF6259` | 等待确认 / 异常（Logo 态 4 + 状态灯） | 代码 `--hud-status-waiting` |
| `status.done` | `rgba(49,209,88,1)` | `#31D158` | 已完成（Logo 态 2 + 状态灯） | 代码 `--hud-status-done` |
| `status.idle-soft` | `rgba(156,160,170,.14)` | — | 空闲软底 / 三态淡背景 | 代码 `--hud-status-idle-soft` |
| `status.working-soft` | `rgba(255,201,40,.14)` | — | 工作中软底 | 代码 `--hud-status-working-soft` |
| `status.waiting-soft` | `rgba(255,98,89,.14)` | — | 等待确认软底 | 代码 `--hud-status-waiting-soft` |
| `status.done-soft` | `rgba(49,209,88,.14)` | — | 已完成软底 | 代码 `--hud-status-done-soft` |
| `dot.update` | `rgba(255,77,79,1)` | `#FF4D4F` | 更新未读红点（5px 徽标 / 7px 灯） | 代码 `--hud-dot-update` |
| `dot.update-ring` | `rgba(0,0,0,.40)` | — | 红点 1px 分离环（压在任何底上都不糊） | 代码 |

> 兼容说明：工程内另有旧任务灯色 `#8E8E93 / #FFB800 / #FF3B30 / #34C759`，与 Logo 四态**近义不同值**，需收敛为一支色板 → 见第 4 节 T5。

---

### 2.6 圆角

| 语义名 | 值 | 用途 | 来源 / 实现变量 |
|---|---|---|---|
| `radius.3` | `3px` | 周期胶囊内段（实现 3.5 规整） | 代码 `--hud-radius-3` |
| `radius.4` | `4px` | 图标按钮命中底（= KD `radius-small`） | KD `--hud-radius-4` |
| `radius.6` | `6px` | 按钮、导航项、Tooltip（= KD `radius-middle`） | KD `--hud-radius-6` |
| `radius.8` | `8px` | 任务行、卡片、系统要求块（= KD `radius-large`） | KD `--hud-radius-8` |
| `radius.12` | `12px` | 设置窗口 / 弹窗（= KD `radius-extra-large`） | KD `--hud-radius-12` |
| `radius.card` | `14px` | 关于窗图例卡 | 代码 `--hud-radius-card` |
| **`radius.panel`** | **`16px`** | **主 HUD 面板圆角（现有值，不改）** | 代码 `--hud-radius-panel` |
| `radius.notch` | `14px` | 刘海条底部圆角（`cornerR`，需与硬件开孔视觉衔接） | 代码 `--hud-radius-notch` |
| `radius.icon` | `20px` | 关于窗 App 图标（88pt 方） | 代码 `--hud-radius-icon` |
| `radius.full` | `999px` | 状态灯、红点、拖拽手柄胶囊、版本胶囊 | KD `--kd-border-radius-circle` |

> KD 圆角刻度为 0/2/4/6/8/12/999，**缺 14 与 16 两档** → 已登记为 HUD 面板级例外（16 为面板真实圆角，与 macOS 悬浮窗视觉惯例一致）。

### 2.7 间距刻度

| 语义名 | 值 | 用途 | 来源 / 实现变量 |
|---|---|---|---|
| `space.2` | `2px` | 行内两行文本的行距 | 代码 `--hud-space-2` |
| **`space.3`** | **`3px`** | **列表行间距**（现有值） | 代码 `--hud-space-3` |
| `space.4` | `4px` | KD 基准最小间距 | KD `--hud-space-4` |
| **`space.6`** | **`6px`** | **区块间距**（现有值） | 代码 `--hud-space-6` |
| `space.8` | `8px` | 面板顶边距 / 图标与文字间距 | 代码 `--hud-space-8` |
| `space.10` | `10px` | 拖拽手柄命中区高、按钮组间距 | 代码 `--hud-space-10` |
| `space.12` | `12px` | 面板左右边距 + 底边距（三向同值） | 代码 `--hud-space-12` |
| `space.16` | `16px` | 分组大间距、按钮组 | 代码 `--hud-space-16` |
| `space.18` | `18px` | 标题行高（= `metrics.header`） | 代码 `--hud-space-18` |
| `space.20` | `20px` | 页脚行高 | 代码 `--hud-space-20` |
| `space.24` | `24px` | 审阅页区块间距、窗口内大留白 | 代码 `--hud-space-24` |
| `space.32` | `32px` | 页面级留白 | 代码 `--hud-space-32` |

> ⚠️ KD 硬性规则要求「间距必须为 4px 整数倍」。`3 / 6 / 10 / 18` 四条不满足，但它们是面板/刘海条的真实原生几何——改掉会导致行距变松、面板变高、刘海条错位。**建议整组登记为 HUD 紧凑刻度例外**，并在代码侧以 `hud/*` 命名空间隔离，避免污染 KD 通用间距 → 见第 4 节 T4。

### 2.8 字号 / 字重 / 行高

| 语义名 | 值 | 字重 | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `font.display` | `22px` | 700 | 关于窗产品名 | 代码 `--hud-font-display` |
| `font.h1` | `13px` | 600 | 分类标题、品牌语（= KD `size-sub-base`） | 代码 `--hud-font-h1` |
| `font.body` | `12px` | 400 | 正文、关于窗说明（= KD `size-small`） | 代码 `--hud-font-body` |
| `font.btn` | `12.5px` | 600 | 按钮文字 | 代码 `--hud-font-btn` |
| **`font.label`** | **`11px`** | **600（semibold）** | **面板标题、任务标题、图例（现有 11pt semibold 标题）** | 代码 `--hud-font-label` |
| `font.mini` | `10.5px` | 500 | 版本胶囊、脚注 | 代码 `--hud-font-mini` |
| **`font.meta`** | **`9px`** | 400 | **行内副信息**：status、meta、时间戳 | 代码 `--hud-font-meta` |
| `font.prompt` | `8.5px` | 400 | 登录引导（本阶段不设计） | 代码 `--hud-font-prompt` |
| `font.micro` | `8px` | 500 | 页脚额度文案 | 代码 `--hud-font-micro` |
| `weight.regular` | `400` | — | 正文 | KD `--kd-font-weight-regular` |
| `weight.medium` | `500` | — | 任务标题、胶囊文字 | 代码 `--hud-weight-medium` |
| `weight.semibold` | `600` | — | 标题、状态、按钮（= KD 唯一 bold 档） | KD `--kd-font-weight-bold` |
| `weight.bold` | `700` | — | 仅关于窗产品名 | 代码 `--hud-weight-bold` |
| `line.title` | `18px` | — | 标题行（= `metrics.header`） | 代码 |
| `line.body` | `17px` | — | 说明段 | 代码 |
| `line.label` | `16px` | — | 标签/工具提示 | 代码 |
| `line.mini` | `15px` | — | 脚注 | 代码 |
| `font.family` | `SF Pro Rounded, ui-rounded, -apple-system, "PingFang SC", …` | — | 全站字体（SwiftUI `.system(design: .rounded)`） | 代码 `--hud-font-family` |
| `font.mono` | `ui-monospace, SFMono-Regular, Menlo` | — | 版本号、命令行片段 | 代码 `--hud-font-mono` |

> ⚠️ KD 字号刻度为 10/12/13/14/16/18/20/24…，**8 / 8.5 / 9 / 10.5 / 11 / 12.5 六档为 macOS 系统字号（`NSFont` 原生值）**，其中 11pt 是全 HUD 的主标题字号。不迁就 KD 刻度（11→12 会让标题溢出、12→13 会让面板膨胀）→ 见第 4 节 T4。

### 2.9 动效时长与缓动

| 语义名 | 值 | 用途 | 来源 / 实现变量 |
|---|---|---|---|
| `dur.instant` | `80ms` | 按下反馈 | 新增 `--hud-dur-instant` |
| `dur.fast` | `120ms` | 悬停过渡、颜色过渡（= KD `--kd-time-fast`） | 代码 `--hud-dur-fast` |
| `dur.normal` | `200ms` | 悬浮面板展开 / 收起 | 代码 `--hud-dur-normal` |
| `dur.window` | `240ms` | 收起后延迟缩窗（≈ KD `--kd-time-normal`） | 代码 `--hud-dur-window` |
| `dur.panel` | `250ms` | 刘海面板展开 / 收起 | 代码 `--hud-dur-panel` |
| `dur.slow` | `400ms` | 页面级过渡（上限） | 新增 `--hud-dur-slow` |
| `ease.standard` | `cubic-bezier(.25,.10,.25,1.00)` | 默认缓动（= KD `--kd-easing-ease`） | KD `--hud-ease-standard` |
| `ease.out` | `cubic-bezier(.16,.84,.44,1)` | 进入 / 展开 | 代码 `--hud-ease-out` |
| `ease.inout` | `ease-in-out` | 循环呼吸、闪烁 | 代码 `--hud-ease-in-out` |
| `ease.kd-transition` | `cubic-bezier(.645,.045,.355,1)` | KD 通用过渡（边框/颜色） | KD `--kd-border-transition-base` |
| `dur.breath` | `2500ms infinite alternate` | Logo 空闲呼吸 | 代码 `hud-breath` |
| `dur.blink` | `1100ms infinite alternate` | 等待确认灯闪烁 | 代码 `hud-blink` |

### 2.10 阴影与发光

| 语义名 | 值 | 用途 | 来源 / 实现变量 |
|---|---|---|---|
| `shadow.cta` | `0 5px 9px rgba(10,108,255,.22)` | 主按钮投影（由品牌绿投影改为蓝） | 代码 `--hud-shadow-cta` |
| `shadow.window` | `0 24px 48px rgba(0,0,0,.48)` | 独立窗口投影 | 新增 `--hud-shadow-window` |
| `shadow.tip` | `0 8px 24px rgba(0,0,0,.48)` | Tooltip 投影 | 新增 `--hud-shadow-tip` |
| `shadow.icon` | `0 10px 14px rgba(0,0,0,.55)` | 关于窗 App 图标 | 代码 `--hud-shadow-icon` |
| `glow.focus` | `0 0 4px rgba(10,108,255,1)` | 焦点发光（= KD 深色 `box-shadow-glow`） | KD `--kd-box-shadow-glow` |
| `glow.status` | `0 0 3px {status.*-soft}` | 状态灯微发光（7pt 小点在近黑底上的可读性兜底） | 代码 |
| `glow.brand-radial` | `radial-gradient(circle, rgba(10,108,255,.28) → 透明)` | 关于窗顶部蓝色氛围光 | 代码 `.about-glow` |

> **面板本身不加投影**：近黑面板浮在桌面顶部时，投影不可见且会造成边缘脏边，只保留 `line.panel` 1pt 描边。

### 2.11 几何常量（真实用量，全部对齐实现）

| 语义名 | 值 | 用途 | 来源 / 实现变量 |
|---|---|---|---|
| `metrics.panel-radius` | `16pt` | 面板圆角 | 代码 `FloatingMetrics` / `--hud-radius-panel` |
| `metrics.panel-h-padding` | `12pt` | 面板内边距（左右） | 代码 `panelHPadding` |
| `metrics.panel-top-padding` | `8pt` | 面板内边距（顶） | 代码 `panelTopPadding` |
| `metrics.panel-bottom-padding` | `12pt` | 面板内边距（底） | 代码 `panelBottomPadding` |
| `metrics.block-gap` | `6pt` | 区块间距 | 代码 `blockSpacing` |
| `metrics.row-gap` | `3pt` | 列表行间距 | 代码 `listSpacing` |
| `metrics.header-h` | `18pt` | 标题行高（含 `font.label` 11pt semibold） | 代码 `headerHeight` |
| `metrics.empty-h` | `24pt` | 空态占位高 | 代码 |
| `metrics.dot` | `7pt` | 状态灯圆点直径 | 代码 `.taskrow .dot` |
| `metrics.update-dot` | `5pt` | 更新红点徽标直径（带 1pt 黑色分离环） | 代码 `.reddot--badge` |
| `metrics.handle-w` | `44pt` | 拖拽手柄胶囊宽 | 代码 `handleWidth` |
| `metrics.handle-h` | `3pt` | 拖拽手柄胶囊高（悬浮面板） | 代码 |
| `metrics.handle-h-notch` | `4pt` | 拖拽手柄胶囊高（刘海面板） | 代码 |
| `metrics.hit-left` | `44pt` | 左侧图标交互区（点击目标下限） | 代码 `FloatingMetrics.iconBox` |
| `metrics.bar-w` | `281pt` | 刘海收起条宽（有刘海屏，= 209 + 2×36） | 代码公式 |
| `metrics.bar-h` | `38pt` | 刘海收起条高（有刘海屏） | 代码 `max(gap,34)` |
| `metrics.bar-w-fallback` | `268pt` | 刘海收起条宽（无刘海屏） | 产品规格 |
| `metrics.bar-h-fallback` | `34pt` | 刘海收起条高（无刘海屏） | 代码 |
| `metrics.notch-corner` | `14pt` | 刘海条底部圆角 | 代码 `cornerR` |
| `metrics.rows-max-h` | `347pt` | 任务列表最大可视高（超出滚动） | 代码 `.rows--scroll` |

---

## 3. 品牌绿 `#00D4AA` 的处置（已拍板）

> **决策（2026-09-29 用户拍板）：品牌绿保留，并升格为全 HUD 唯一的品牌/交互主色，取代 KD 蓝 `#0A6CFF`。** 底色保持 `#0F0F11`；紫色品牌氛围光保持原样不变。

### 3.0 落地映射（实施照此改）

| 位置 | 旧值（KD 蓝） | 新值（品牌绿） |
|---|---|---|
| `accent.normal` | `#0A6CFF` | `#00D4AA` |
| `accent.hover` | `#3B89FF` | `#22E0BB` |
| `accent.pressed` | `#0557D6` | `#00A98A` |
| `accent.disabled` | `rgba(10,108,255,.40)` | `rgba(0,212,170,.40)` |
| `accent.soft` / `accent.track` | `rgba(10,108,255,.16 / .22)` | `rgba(0,212,170,.16 / .22)` |
| `line.focus` / `glow.focus` | `#3B89FF` | `#00D4AA` |
| `shadow.cta` | `rgba(10,108,255,.22)` | `rgba(0,212,170,.22)` |
| `text.on-accent` / `accent.on` | `#FFFFFF` | **`#0F0F11`（深墨）** |

**三条硬规则**：
1. **绿底必须配深墨字**：品牌绿是亮色（相对亮度高），白字压绿只有 ≈1.9:1，不可用；`accent.on = #0F0F11` ≈ 9.8:1。适用于周期胶囊选中段、登录引导按钮、关于页主按钮等一切绿实底控件。反之「绿描边 / 绿文字压深色底」对比度足够，保持品牌绿前景不变。
2. **语义分工**：品牌绿只用于**交互与额度**（按钮、进度、选中、焦点、链接）；状态色 `status.idle #9CA0AA` / `status.working #FFC928` / `status.waiting #FF6259` / `status.done #31D158` 只用于**状态语义**，两者不得同屏紧邻。
3. **唯一例外**：关于内容的顶部氛围光仍用紫色 `#937EE6 28% → #4526BF 14% → 透明`（用户明确要求保持不变），只作氛围、不参与交互与语义。

> 以下 §3.1–§3.4 是**决策前**的方案分析，保留作背景，**一律以 §3.0 为准**（其中「品牌绿退出售」的推荐已被用户否决）。

### 3.1 现状与问题

| 现状 | 位置 | 问题 |
|---|---|---|
| `#00D4AA` 用于**页脚额度**文字/进度 | 悬浮面板页脚 | 与 `status.done #31D158` 同屏会出现**两个绿**，语义歧义：「绿 = 额度充足」还是「绿 = 任务完成」？ |
| `#00D4AA` 用于**关于窗主按钮** | About 主 CTA | 与设计语言「交互主色 = 品牌蓝 `#0A6CFF`」直接冲突：一个视图内出现两种饱和色，且按钮不表语义、纯属品牌色 |
| `#00D4AA` + 蓝 + 四态色 | 关于窗（图例卡） | 单视图饱和色达 **6 种**，远超 KD「同屏 ≤ 2 种饱和色」的硬约束 |

`#00D4AA` 是**青绿**，介于 KD 的 `teal-7 #0CAF76` 与 `teal-8 #3BC99A` 之间，与 KD 任一语义色都不重合 —— 也就是说它既不是 KD 的 success，也不是 KD 的品牌色，是一支**孤立的品牌装饰色**，恰好落在 P3 原则（功能色只表语义、禁止装饰）的禁止区。

### 3.2 三个方案

| 方案 | 做法 | 代价 | 与现有实现（`_css/hud.css`）的关系 |
|---|---|---|---|
| **A. 完全退出（推荐）** | 关于窗主按钮 → `accent.normal #0A6CFF`；页脚额度文字 → `text.secondary`；额度进度条填充 → `accent.normal`；额度**临界/耗尽**时才用 `status.waiting` 表语义 | 需删掉 `--hud-quota*` 三个变量，改动 2 处界面 | 与现有 `--hud-quota` 冲突，需同步改 §2.5 |
| **B. 单一语义降级（保守）** | `#00D4AA` 降级为**「额度」这一件数据可视化的专用色**，仅允许出现在额度进度条填充与额度数字上，禁止出现在任何文字以外的控件底（含主按钮） | 保留一支持续存在、与 KD 语义无关的饱和色；仍需保证同屏不超 2 色 → 页脚区不能再出现蓝 | 与现有实现**一致**（`--hud-quota / -soft / -on`） |
| **C. 并入 success 语义** | 直接把 `#00D4AA` 换成 `status.done #31D158` | 额度充足 ≠ 任务完成，语义撞车，反而更乱 | 需改 `--hud-status-done` |

### 3.3 建议：方案 A，理由三条

1. **额度不是状态，是数量。**「今天用了 82% 额度」本质上是一个**进度读数**，不是成功/失败语义。KD 的答案是：进度用控件承载（`accent` 填充的进度条），状态色只在**阈值越线**时出现（`< 20%` 用 `status.waiting` 橙红）。这样才能同时满足「功能色只表语义」和「同屏 ≤ 2 饱和色」。
2. **一个视图不该有两个绿。** 页脚额度绿 + 任务行 `#31D158` 完成绿同屏时，用户需要额外学习才能区分二者；删掉额度绿后，「绿 = 完成」成为全 HUD 唯一解释，认知成本归零。这与 P1「饱和色只做语义」是同一件事。
3. **关于窗主 CTA 必须是品牌蓝。** 主按钮是全 HUD 唯一的最高优先级交互，它应该指向全产品统一的交互主色 `#0A6CFF`；现有实现的按钮阴影已从绿改为蓝（`--hud-shadow-cta: 0 5px 9px rgba(10,108,255,.22)`），说明方向已经走到一半，只差把底色一起换掉。

### 3.4 方案 A 的落地映射（实施时照此改）

| 原位置 | 原值 | 改为 | 语义理由 |
|---|---|---|---|
| 关于窗主按钮底 | `#00D4AA` | `accent.normal #0A6CFF`（hover `#3B89FF` / pressed `#0557D6`） | 交互主色统一 |
| 关于窗主按钮投影 | 绿投影 | `shadow.cta`（蓝 .22） | 与底色同族 |
| 页脚额度文字 | `#00D4AA` | `text.secondary`（额度充裕）/ `status.waiting`（临近耗尽） | 文字走中性档，语义只在越线时出现 |
| 页脚额度进度条填充 | `#00D4AA` | `accent.normal`；`accent.track` 作已填充软段 | 进度属控件，不属状态 |
| 周期胶囊「当前段」实底 | `rgba(0,212,170,.85)` | `accent.normal` 或 `accent.soft`（选中语义） | 选中是交互态，用品牌蓝 |
| 变量清理 | `--hud-quota`、`--hud-quota-soft`、`--hud-quota-on` | 删除；如需过渡期别名，先指向 `--hud-accent` | 避免留下第二个绿 |

> 若品牌侧坚持「额度必须有专属识别色」，则退到**方案 B**，但需接受：`#00D4AA` 被登记为**唯一一支非 KD 色**，且页脚区禁止再出现品牌蓝，且必须在设计规范里写明使用边界（仅进度条填充 + 仅额度数字）。此决策需用户拍板 → 第 4 节 T1。

---

## 4. 待用户确认

| # | 事项 | 建议 | 影响面 | 阻塞 |
|---|---|---|---|---|
| **T1** | **品牌绿 `#00D4AA` 处置** | ✅ **已拍板：保留品牌绿，并升格为唯一品牌/交互主色，取代 KD 蓝 `#0A6CFF`**（见 §3.0；绿底一律配深墨字 `#0F0F11`） | 全 HUD 交互色、页脚额度、周期胶囊、关于主按钮 | 已闭环 |
| **T2** | 面板底色定档 | ✅ **已拍板：保持 `#0F0F11`**（不用 KD 的 `#121212`，避免挂在纯黑刘海下露色差） | 全部界面基调 | 已闭环 |
| **T3** | 「悬浮层」是否用 `surface.raised = rgba(255,255,255,.06)`（≈`#1D1D1F`，对标 KD `background-group #1F1F1F`） | 采用。但需确认 6% 白在近黑底上是否够可见（实测建议 ≥5%，且必须同时有 `line.divider` 兜底） | 设置窗口导航、面板内次级控件 | 不阻塞骨架 |
| **T4** | **KD 例外登记**：间距 `3/6/10/18`、字号 `8/8.5/9/10.5/11/12.5`、圆角 `14/16` 均不在 KD 刻度上 | **整组登记为「HUD 紧凑刻度 + macOS 原生字号」例外**，以 `hud/*` 命名空间隔离。若用户要求严格贴 KD 刻度，则面板行距会从 3→4、字号 11→12，面板会变胖约 8–10% | 全部几何；改则需重排 | 需要拍板（默认按例外执行） |
| **T5** | **任务灯与 Logo 四态色是否收敛**：现有任务灯 `#8E8E93 / #FFB800 / #FF3B30 / #34C759` vs Logo 四态 `#9CA0AA / #FFC928 / #FF6259 / #31D158` | **收敛为一支**（取 Logo 四态值）。同屏「任务行状态灯 + 顶部 Logo」同时出现两组近义色，是最容易看出「不精致」的地方 | 任务行状态灯、关于窗图例 | 不阻塞骨架 |
| **T6** | 更新红点 `#FF4D4F` 是否并入语义色：与 `status.waiting #FF6259` 存在 2 个红 | 保留 `#FF4D4F`（更饱和、专表「有更新」），但在规范中明确「红点与状态灯不得相邻出现」 | 关于窗更新行、设置入口 | 不阻塞骨架 |
| **T7** | 禁用态是否统一改用 KD 的 `opacity:.4`（而非 `text.disabled` 灰色） | **采用 KD 规则**：交互控件禁用走 `opacity .4`；`text.disabled` 仅用于静态不可用文案。二者并存需用户确认 | 按钮、导航项、输入框 | 不阻塞骨架 |
| **T8** | 深色下**文字对比度自检结论是否接受**：`text.tertiary .55`（`#8E8E8E` on `#0F0F11`）≈ **6.4:1** ✅；`text.quaternary .46`（`#797979`）≈ **4.6:1** ✅（AA 正文临界通过）；`text.disabled .30`（`#545454`）≈ 2.3:1 ❌ 仅限非必要信息 | 接受现状，但**禁止** `text.disabled` 承载任何必要信息（版本号、系统要求等需提到 `tertiary`） | 脚注、空态、关于窗 | 不阻塞骨架 |
| **T9** | ~~界面 HTML 排期~~ **已交付**：主面板 / 设置窗口 / 关于弹窗 / 刘海形态 四面 HTML 已出（见 §7） | 剩余面（登录窗、更新提示）待补 | 第二阶段范围 | 已闭环 |
| **T10** | 页脚额度区改写为「已用/总量 + 进度条」 | ✅ **已拍板并按此实现**：① 周期切换胶囊（**「日 / 月」，日在前、月在后**，不得写「7天/30天」）→ ② 「已用 1,240 / 2,000 点」+ 细进度条（`accent` 填充 / `accent.track` 底）→ ③ 铃铛 + 未读数 → ④ 齿轮（5pt 更新红点）。数据源 `UsageAPI.Limit`（`used/total/remain/percent`） | 页脚（悬浮面板与刘海展开共用）、`HUDUsageFooter` | 已闭环 |
| **T11** | 关于弹窗紫色品牌光晕处置 | ✅ **已拍板：保持不变**（`#937EE6 28% → #4526BF 14% → 透明`，唯一例外，只作氛围） | 关于内容顶部 | 已闭环 |
| **T12** | 设计稿中的示例数据（昵称「李柯」、企业「金山办公」、版本 `v1.4.2 (2410)` / `v1.5.0`）均为**占位**，不代表真实取值 | 实现时一律取真实数据（当前 1.4.5 / build 14）；HTML 稿保留占位即可，不作为验收依据 | 设置窗口、关于弹窗 | 不阻塞 |
| **T14** | 悬浮图标新增的半透明 chip（白 6%）在**浅色壁纸**上可能看不清（图形自带深色底时反而看不清外圈） | 建议接受：chip 只作弱承托，不追求在浅壁纸上也醒目；如果实测看不清再加 `1px` 深色外描边或提高描边到白 14% | 悬浮模式图标 | 不阻塞 |
| **T15** | 登录窗第 4 态（校验失败）颜色：设计稿取 `#FFC928`（对齐代码 `NSColor.systemOrange`）还是用 `status.waiting #FF6259` | 建议 `#FFC928`（与现实现一致，改动最小） | 登录窗 | 待拍板 |

---

## 5. Acceptance Contract（验收判据）

后续任一界面产出，必须同时满足以下全部条目才可判为通过：

1. **Token 全覆盖**：界面 CSS 中不得出现硬编码色值（含 `rgba(255,255,255,.x)` 这类半透明白）——一律引用本表 token；字号、圆角、阴影同理。
2. **单一饱和色**：任一视图内饱和色 ≤ 2 种，且其中一种是 `accent.normal`。
3. **面板无投影**：面板只靠 `line.panel` 1pt 白 12% 描边与背景分离。
4. **禁用态**：交互控件统一 `opacity: .4`；`text.disabled` 不出现在任何必要信息上。
5. **焦点可达**：所有可交互元素有 `outline: 2px solid accent.line; offset: 1px` 的可见焦点环，Tab 序与视觉序一致。
6. **例外已登记**：任何偏离 KD 刻度的值，必须同时出现在 §2 对应表与 §4 T4 清单中，不允许「静默偏离」。
7. **动效可降级**：`prefers-reduced-motion` 下所有动画退化为终态；关键状态变化不依赖动画传达。
8. **离线自洽**：无任何外链（字体 / 图片 / CDN / 埋点），图标为内联 SVG，无手写 path 之外的外部依赖。
9. **浏览器基线**：Chromium 104 —— 禁用 `:has()`、`color-mix()`、CSS Nesting、`@container`。
10. **几何一致**：面板左右 12 / 顶 8 / 底 12、区块 6、行距 3、标题行高 18、状态灯 7、手柄 44×3、刘海条 281×38（无刘海 268×34）逐项对齐实现。

---

## 6. 变更约定

| 场景 | 动作范围 |
|---|---|
| `design_mutation`（微调 token） | 只改 §2 对应 token 行 + §4 相关条目；不动原则与验收条目 |
| `restyle`（换风格/换模板） | 重写全文 + `manifest.json` + `references/` 重建 |

> 资源索引见 [manifest.json](./manifest.json)；审阅总页见 [references/index.html](./references/index.html)；KD 官方 token 事实源副本见 [references/_css/tokens.css](./references/_css/tokens.css)，HUD 校准层见 [references/_css/hud.css](./references/_css/hud.css)。

---

## 7. 界面规范（第二阶段已交付）

四个面的 1:1 HTML 稿均已产出，逐个可直接打开对照；下列规范是**实现时的唯一依据**。

### 7.1 悬浮窗展开内容 — `references/panel-main.html`

- 面板：宽 `281pt`（与刘海条同宽，收起/展开同宽）；高按内容，`120 / 300 / 420`（最小/默认/最大），1–10 条之间；`radius.panel 16`；描边 `line.panel` 1pt 白 12%；**无投影**
- 区块顺序（间距 `space.6`）：标题行 `18pt` → 任务列表 → 页脚 `20pt` → 拖拽手柄（胶囊 `44×3`、命中区仅最底 `space.10`）
- 标题行：「Comate HUD」`font.label 11/600` `text.secondary`；右侧新建任务按钮 `18×18`、`radius.4`、图标 `11pt`、hover `surface.hit`
- 任务行 `30pt`：状态灯 `7pt`（`status.*`）→ 来源图标 `8pt`（云端 icloud / 本机 folder，`text.tertiary` / `text.quaternary`）→ 标题 `font.label 11/500` `text.primary`（hover 至 `.92`→`1.0`）→ 第二行：状态文案 `9/600`（取状态色）+ 副信息 `9/400`（「30天 N 点」或「—」）+ 相对时间 `9/400`（`text.quaternary`）→ 尾部 `arrow.up.right 9pt`（hover `.2`→`.5`）；行底 `surface.row .04` / hover `.10` / pressed `.14`，`radius.8`，内边距 `3 / 6`；悬停提示取 `task.hoverHelp`（内含「正在等你回答：…」等）
- 空态：「暂无任务」，占位高 `24pt`，`text.quaternary`
- 页脚（v2 两行结构，高 **34pt** = `padding 6 + 第1行 14 + 行距 4 + 进度条 4 + padding 6`）：
  - **第 1 行**：左 = 日/月 切换胶囊（双段、选中段 `accent.normal` 且文字 `accent.on #0F0F11`，标签只写「日 / 月」）→ **紧贴**（间距 `6pt`）「已用 1,240 / 2,000 点」（`font.micro` 10pt、`tabular-nums`）；右 = 铃铛（`bell.fill` + 未读数）+ 齿轮（`gearshape.fill` + 右上 `5pt` 更新红点 `dot.update`），两者命中区 `32×22`、`radius.5`，hover `surface.hit`，**x 坐标固定不随左侧数字伸缩**
  - **第 2 行**：进度条独占一行、左对齐、占满可用宽度（宽 209pt / 高 4pt / `radius.meter 2`），填充 `accent.normal`、底 `accent.track`；百分比数字（10pt `tabular-nums`）紧贴条右端、间距 `6pt`，占位固定 36pt
  - **防跑版规则（必须遵守）**：数字一律 `tabular-nums`；超长按中文习惯缩写（≥1 万 →「1,234.6 万」、≥1 亿 →「12.3 亿」，保留 1 位小数）；空间不足先降级去掉「已用」二字；**禁止**省略号截断、「…」占位、或撑出第三行。三档实测：①`1,240 / 2,000` 左宽 146.4（0.82×179）②`12,345,678 / 20,000,000` → 缩写+去「已用」后 169.1（0.94）③`999,999,999 / 1,000,000,000` →「10.0 亿 / 10.0 亿」158.7（0.89）；三档铃铛 x=185 / 齿轮 x=219 恒定
  - **兜底三态**：无数据（`已用 — / — 点`，不写 0）/ 加载中（骨架：胶囊 36×17、文字 104×10、图标 32×22、进度条 209×4、百分比 36×10）/ 未登录（额度位换成登录引导按钮，`accent.normal` 底 + `#0F0F11` 深墨字，实宽 137）——三者页脚高度仍为 34pt，不留空
- 状态变体：行 hover / pressed / 加载骨架 / 空态 / 未登录 / 手柄 hover 与拖拽中
- **与现状的差异（T10 已拍板）**：页脚额度改为「① **日 / 月 周期切换胶囊（在最前，日在前）** → ② 已用/总量 + 进度条 → ③ 铃铛 + 未读数 → ④ 齿轮」；标签只能写「日 / 月」

**v2 刻度（按用户「字太小、太挤」反馈上调，四种展开形态与任务行共用）**：

| 项 | v1 | v2 |
|---|---|---|
| 标题行文字 / 行高 | 11pt / 18pt | **12.5pt semibold / 20pt**（刘海展开内行高 17pt） |
| 任务行标题 | 11pt | **12.5pt medium** |
| 任务行第二行 | 9pt | **10pt** |
| tooltip 文案 | 9pt | **10pt / 行高 13** |
| 空态「暂无任务」 | 9pt | **11pt** |
| 行高 / 行距 / 行内水平内边距 | 30 / 3 / 6 | **34 / 4 / 7** |
| 面板内边距 / 区块间距 | 12 / 8 / 12 · 6 | **14 / 10 / 14 · 8** |
| 状态灯 | 7pt | **8pt** |
| 面板高度（最小/默认/最大） | 120 / 300 / 420 | **132 / 340 / 460**（主面板实测 281×288） |
| 页脚 | 高 20 · 额度 8 · 胶囊段 13×11 · 图标 9 · 未读数 9 | **两行结构 · 高 34 · 额度 10 · 胶囊段 17×14（段内 9.5）· 图标 10.5 · 未读数 10 · 侧热区 32×22 · 进度条 209×4 · 百分比占位 36** |

> 行高 34 高于 KD 紧凑刻度 32，属已登记例外（T4）；行内垂直方向不再额外加 padding（行高已含 `18 + 2 + 14`）。

### 7.2 设置窗口（本期新增形态）— `references/settings.html`

- 窗口 `520 × 460pt`，系统标题栏（标题「设置」），不做自定义交通灯；窗口投影 `shadow.window`
- 左分类导航 `148pt`：`surface.raised` 底 + 右侧 `line.divider`；4 项：账号 / 显示 / 通用 / 关于；选中态 `surface.hit` + 文字 `text.primary`，未选中 `text.tertiary`；项宽 `title 12/600`
- 右内容区：内边距 `18 / 20 / 20`；分区标题 `font.label 11/600` `text.secondary`；分区卡片 `surface.card` + `line.card` 描边 + `radius.8`；行高 `34pt`，行间 `line.divider`
- 控件映射（原生可直接实现）：单选 `NSButton(radio)`（选项 `min 132`）、下拉 `NSPopUpButton`（高 `24pt`）、开关 `NSSwitch`（`34×20`）、动作按钮 `NSButton`（次按钮 `text.accent`、`24pt` 高）、文本域用 `NSTextField`
- 必须覆盖的项：账号（登录/登录失效重新登录/账号+企业/退出登录）、显示模式（刘海·悬浮）、刘海所在屏幕（含「跟随主屏」）、最近记录条数（1–10）、恢复默认高度（动作）、开机自启动（开关）、检查更新（三态 + 红点）、进关于
- **「关于」页（新增，承载原关于弹窗的全部内容）**：应用图标 `88×88`（`radius.icon 20`）→ 产品名「Comate HUD」 → 版本胶囊 → 主张「让 AI 干活，你只管看灯」→ 描述 → 四态图例卡 → 特性列表（3 行）→ 署名「通过 WPS Comate 应用开发能力 Vibe Coding 实现」→「访问官网」主按钮 → 底部文字链接「检查更新 · 意见反馈 · comate.wpsgo.com」→ 更新三态。顶部保留紫色氛围光（T11，唯一例外）。**原独立关于弹窗退场**；菜单项「关于 Comate HUD」改为直接打开本窗口并定位到「关于」页
- 条件出现：「刘海所在屏幕」仅刘海模式且多屏；「恢复默认高度」仅自定义过高度（详见设计和原）。隐藏时不留空位
- 状态：登录失效警示态、未登录态、单选选中/未选中、按钮 hover/focus、开关 on/off；**警示不用红色块**，走 `status.waiting` 文字 + 二次确认入口

### 7.3 关于内容 — 已并入设置窗口「关于」页（`references/settings.html`；`about.html` 仅存档）

> **形态变更（2026-09-29 用户拍板）**：原独立关于弹窗**退场**，其内容整体并入设置窗口的「关于」页；紫色氛围光按 T11 保留。`references/about.html` 保留为历史稿，不再作为交付面。菜单「关于 Comate HUD」→ 打开设置窗口并定位「关于」页。

以下为并入内容的规范（尺寸按新容器 `560×480` 适配）：

- 独立窗口 `420 × 556pt`，底 `surface.panel` `#0F0F11`，内边距左右 `30` / 顶 `32` / 底 `22`
- 自上而下：品牌氛围光晕（见 T11）→ 应用图标 `88×88`（`radius.icon 20`、投影 `shadow.icon`、内描边白 9%）→ 产品名「Comate HUD」`22/700` rounded 纯白 → 版本胶囊「版本 X.Y.Z」`10.5/500`（胶囊底白 7% + 描边 7%）→ 主张「让 AI 干活，你只管看灯」`13/600` accent → 描述（`12pt`、行距 5、居中、`max-width 300`）→ 四态图例卡（`radius.card 14`，空闲/已完成/工作中/等待确认）→ 特性列表（3 行，勾选 `accent`）→ 署名「通过 **WPS Comate 应用开发能力 Vibe Coding** 实现」→ 主按钮 `150×34`（`accent.normal` + `shadow.cta`）/ 次按钮 `96×34` → 文字链接「检查更新 · 意见反馈 · comate.wpsgo.com」
- 更新三态（与设置菜单同源）：未检测→「检查更新」、已最新→「已是最新版本 vX.Y.Z」、有新版→「检测到新版 vX.Y.Z」+ `5pt` 红点；主按钮层级仅在「有新版」时变化
- 所有真实文案以 `HUDShared.swift` 的 `AboutHUDView` 为准，不得改写

### 7.4 刘海形态 — `references/notch.html`

- 收起条：`281×38`（有刘海，中段 `209pt` 是硬件开孔，**不可绘制**）/ `268×34`（无刘海 fallback）；底 `surface.bar` 纯黑（不用面板底，避免在纯黑开孔旁露色差）；底角 `radius.notch 14`；顶部直角与屏顶对齐
- 两翼各 `wingWidth 36`：左翼 logo 中心固定 `x=18` 垂直居中（刘海条内图形 `28pt`，悬浮模式 `30pt`）；右翼「+」新建任务按钮（视觉 `18×18`、`radius.4`、图标 `11pt`、hover `surface.hit`）
- 展开面板：**只改高度 y**，左右边缘全程不动；顶部 `38pt` 仍是刘海本体（不可绘制区域）；内容区 = 标题行 `18pt` + 任务列表 +（页脚）+ 手柄（不映射到刘海区）；含「有任务 / 空态」两版
- 五态小样（含本次新增的「异常」）与动效参数见 §8

---

### 7.5 登录窗（本期新增面）— `references/login.html`

严格照 `Sources/LoginWindow.swift` 的事实，**不得改动硬约束**：

- **形态**：独立 `NSWindow`（`.titled/.closable/.resizable`），标题「登录 WPS 账号」；**不是面板内的 sheet**（HUD 面板是非激活 borderless 面板，挂不上 sheet，关于窗也是因此走独立窗）。
- **尺寸**：内容区 `460×820`（含系统标题栏时 frame 高 848），可缩放但**最小 `460×700`**。
- **固定头 78pt**：说明区（两行，原文：登录后 HUD 才能显示未读消息与额度用量。／HUD 只保存本次登录的凭证，不会读取你的文档内容。，`11.5pt` secondary）→ 状态行（`11.5pt`）→ 通栏分隔线 `1px`。
- **WebView 高 ≥ 620pt（硬约束）**：`comate.wps.cn/web` 的登录页在视口高 `<600pt` 时会自身塔陷（主登录按钮被压成一条），窗口最小 700pt 对应 WebView 622pt，余量仅 2pt——**实现时不得再减小窗口高度**。WebView 区在稿中为中性占位（内嵌真实登录页，设计稿只约束外壳与文案）。
- **状态行四态**：① 默认「请在下方完成登录（扫码或账号密码）」（灰）② **校验中**（本稿新增文案：「正在校验登录状态…」，灰 + 三点脉冲点缀，不用转圈）③ 成功「登录成功，正在恢复数据…」（绿字 `#00D4AA`，持续 `0.9s` 后自动关窗）④ 失败「已取得登录凭证但服务端仍拒绝，请关闭窗口后重试」（橙，`#FFC928` 待拍板 T15；仅在第 3 次探测失败后出现）。
- **行为标注**：关窗 = 放弃本次登录（凭据只在内存、不落盘）；登录成功后自动关窗。

### 7.6 更新提示（本期新增面）— `references/update.html`

现状（代码事实）：**没有独立更新窗**，只有三处入口——菜单项三态（「检测到新版 vX」/「已是最新版本 vX」/「检查更新」）、菜单栏图标右上角红点、设置窗口「关于」页的更新三态。数据来自 `versions.json` 与 GitHub Releases atom feed。

本稿新增一个**独立小窗**（同样因为面板挂不上 sheet）：

- 尺寸 `420×320`（不可缩放），标题「Comate HUD 有可用更新」。
- 内容：应用图标（`56×56`）→ 版本行「`v1.4.5` → `v1.4.6`」（`tabular-nums`）→ 更新说明区（按 `versions.json` changelog 的 type 标签分「新增 / 优化 / 修复」三组圆点列表；**分组靠文案不靠颜色**，避免与状态色撞语义）→ 主按钮「前往下载」（`accent.normal` 底 + **`#0F0F11` 深墨字**）→ 次按钮「稍后」→ 文字链接「跳过此版本（不再提示）」。
- **四态**：① 有新版 ② 检查中（按钮禁用：底 `accent.disabled`、文字降到白 55%，**不再用深墨**）③ 已是最新（无主按钮，单「好」+ 一行说明）④ 检查失败（一行说明 + 主按钮改「重试」+ 次按钮「关闭」）。
- 稿中另附「与三个既有入口的关系」对照区（菜单项三态 / 红点三处出现位 / 关于页三态）。

### 7.7 悬浮窗图标（本期新增面）— `references/floating.html`

同一套五态指示图形，两种尺寸与两种承托：

| 项 | 刘海收起条 | 悬浮模式（本稿） |
|---|---|---|
| 图形尺寸 | `28pt` | `30pt` |
| 底色 | 纯黑 `#000000` | **半透明 chip**：`36×36`、`radius 10`、底 `rgba(255,255,255,.06)`、描边 `1px rgba(255,255,255,.08)` |
| 命中盒 | 无独立命中盒（单翼宽 36） | `44pt`（iconBox，**chip 不得改变它**） |
| hover | 无 | 底 `.10`（按下 `.14`、展开中 `.12`） |
| 随窗口移动 | 是 | 是 |

- 嵌套关系（实测）：窗口 60 ⊃ 命中盒 44 ⊃ chip 36 ⊃ 图形 30；chip 不超出窗口可用区（pad 8pt）。
- 展开形态：面板从图标**下缘锚点**展开（收起态面板在窗口外被裁掉）；稿中给出收起 / 展开中（`scale .94`）/ 展开三帧与锚点标注。
- 风险：白 6% 的 chip 在**浅色壁纸**上可见度低（登记 T14）。

## 8. 动效规格（含红灯五态）

> 这是本次对 `LogoMotion.swift` 的改造依据。现有实现的问题：`animated` 分支写为 `if state == .waiting { return redBlinking }`，导致「异常」红完全不播动画；且动画启动只在 `\.id(state)` 重建时发生，`redBlinking` 翻转不能启停。

| 元素 | 时长 | 缓动 | 循环 | 备注 |
|---|---|---|---|---|
| 面板展开/收起 | `250ms` | `ease.standard` | 一次 | 同时 `scale .94→1` + `opacity 0→1` |
| 行 hover / 按钮 hover | `120ms` | `ease.standard` | 一次 | 只改颜色，不做位移/缩放 |
| 面板进出场（状态切换） | `520ms` | `ease.out` | 一次 | `scale .92` + `opacity` |
| 状态色过渡 | `500ms` | `ease.inout` | 一次 | 仅色相变化 |
| 空闲：呼吸点 + 外扩涟漪（**方案 A：已加大振幅**） | 呼吸 `1.9s` alternate / 涟漪 `4.2s` | `ease.in-out` / `ease-out` | 无限 | 呼吸点 `scale .55→1.18`、`opacity .32→1`；涟漪 `scale .62→1.46`、`opacity .46→0`。**28pt 下涟漪直径 2.43→5.72pt（Δ3.29 ≥ 3pt 可辨）**；仍为五态中最安静的一档（单位时间视觉移动量：工作中 68.3 > 已完成 13.2 > 等待确认 1.22 > 异常 0.75 > **空闲 0.39 pt/s**） |
| 工作中：三段光轨 | `1.15s` | `linear` | 无限 | 三段相位 `0 / .92 / .85`，同向追逐，不可逆转 |
| 等待确认（红·要你回应） | `1.6s` | `ease-out` | 无限 | 双圈脉冲 `opacity .38→0`、`scale .73→1.24`，错相 `0.72s`；感叹号浮起 `-5px`、`1.15s ease-in-out alternate` |
| **异常（红·新增，提示但不催）** | `2.4s` | `ease-out` | 无限 | **单圈**脉冲（尺寸同 `waitingWave`、透明度峰值降至 `.28`）；感叹号**不浮动**，改为极缓透明度呼吸 `1.6s` 内 `.72↔.9` |
| 已完成：对勾 + 星点 | `620ms` / `860ms` | `ease-out` | 一次 | 对勾 `0→1` 描出后星点依次聚开 |
| 消息铃铛打开中 | `800ms` | `linear` | 无限 | 旋转图标替代铃铛；打开完成即停 |

**可访问性回退**：系统「减弱动态效果」开启时，以上动画全部退化为终态静态帧；状态必须仍能用字符、颜色与形状区分（不得只靠动画传达）。

**实现要点（避免重蹈覆辙）**：
1. 红灯动画的启动条件不再引用 `redBlinking`；「等待确认」与「异常」是两个不同的状态（建议在 `TaskLight.red` 下再分支，或在 `LogoMotionState` 新增 `.fault` 成员），不得再用一个布尔量兼作控制器。
2. 动画启停必须响应状态与红闪标志的**变化**，不能只依赖视图重建（现 `\.id(state)` 的写法需改，例如用 `.onChange(of:)` 或把通道拆成独立子视图）。
3. `reduceMotion` 仍作为最高优先级开关。

### 8.1 设计稿动效的真伪验证（必须用这套方法，不要靠「看起来在动」）

实际踩过的坑：动画曾全写在 `<defs>` 的模板图元上，而页面可见实例是 `<use>` 克隆 —— `document.getAnimations()` 能数出 12 个动画，但每个目标的 `getBoundingClientRect()` 都是 `0x0`（动画发生在不可渲染的模板上），冻结到不同时刻整页像素差为 **0**：页面实际是静止的，却很容易误判为「已实现」。修法：把图元**内联**进每个可见实例，动画写在图元自身。

接受的验证方法（任一即可，推荐两者都做）：
1. **动画目标体检**：`document.getAnimations()` 中不得有目标的 `getBoundingClientRect()` 宽高为 0；目标不得位于 `<defs>` 内。
2. **冻结时刻法**：脚本把每个动画 `currentTime` 设为 `0 / 400 / 800` 并 `pause()`，分别量目标的 `getBoundingClientRect()` 与 `computed opacity` —— 必须有实例发生变化（例：等待确认双圈 5.6→8.3 / 8.0→9.5、透明度 .38→.12/.002；异常单圈 5.6→7.3）。比截图更稳，不受无头渲染环境限制。

另一个必须知道的坑（静默致几何失效）：HTML tokenizer 会把「未加引号且紧邻 `/>`」的属性值吃进 `/`，`<circle r=42/>` 会解析成 `r="42/"`（非法 → **r=0**）且标签不再自闭合。写内联 SVG 时凡数值属性一律加引号。

> 另：本机屏幕锁定时无头 chromium 截屏会挂死（依赖显示合成器），此时改用冻结时刻法核对几何，或解锁后再截图。
