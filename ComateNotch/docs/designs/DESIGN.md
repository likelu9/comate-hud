---
version: "1.0"
stage: "skeleton"
style: "dark-minimal"
scope: "设计规范骨架（token + 原则），不含界面实现"
palette:
  primary: "#0A6CFF"
  secondary: "#3B89FF"
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
面板底保持近黑 `surface.panel = #0F0F11`（与物理刘海无缝的收起条再用纯黑 `surface.bar = #000000`）。层级不靠「越上层越亮」的堆色法，而靠 KD 深色灰阶的三档背景 + 两级分隔线。除品牌蓝 `#0A6CFF` 外，内容区不出现饱和色；红/橙/绿只允许出现在任务状态灯、Logo 四态、更新红点三个语义位。

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
| `text.on-accent` | `rgba(255,255,255,1)` | `#FFFFFF` | 品牌蓝实底上的白字 | KD `--hud-text-on-accent` |
| `text.strong` | `rgba(245,245,245,.92)` | `#E3E3E3` | 脚注中的加粗关键值 | 代码 `--hud-text-strong` |

### 2.3 描边与焦点

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `line.panel` | `rgba(255,255,255,.12)` | `#292929` | 面板描边 **1pt**（面板唯一容器装饰，不用阴影） | 代码 `--hud-line-panel` |
| `line.card` | `rgba(255,255,255,.07)` | `#1F1F21` | 卡片 / 独立窗口描边 | 代码 `--hud-line-card` |
| `line.divider-strong` | `rgba(255,255,255,.14)` | `#2C2C2E` | 分组间强分隔（= KD 深色 `line-regular` 14%） | 新增 `--hud-line-divider-strong` |
| `line.focus` / `accent.line` | `rgba(59,137,255,1)` | `#3B89FF` | 键盘焦点环 `outline: 2px` + `offset 1px` | 代码 `--hud-accent-line` |
| `line.on-accent` | `rgba(255,255,255,.09)` | — | 蓝色实底控件内描边 | 代码（关于窗图标） |

### 2.4 交互主色（KD 品牌蓝，内容区唯一饱和色）

| 语义名 | 深色值（实现） | 等效 hex | 用途 | 来源 / 实现变量 |
|---|---|---|---|---|
| `accent.normal` | `rgba(10,108,255,1)` | `#0A6CFF` | 主按钮底、选中态、进度、品牌语 | KD / 代码 `--hud-accent` |
| `accent.hover` | `rgba(59,137,255,1)` | `#3B89FF` | 悬停（KD blue-5） | 代码 `--hud-accent-hover` |
| `accent.pressed` | `rgba(5,87,214,1)` | `#0557D6` | 按下（KD blue-7/8 深支） | 代码 `--hud-accent-pressed` |
| `accent.disabled` | `rgba(10,108,255,.40)` | `#0A6CFF @40%` | 禁用（= KD `--kd-opacity-disabled` 0.4） | KD |
| `accent.soft` | `rgba(10,108,255,.16)` | — | 选中行底、激活态底、软强调 | KD `state-pressed-public` / `--hud-accent-soft` |
| `accent.on` | `rgba(255,255,255,1)` | `#FFFFFF` | 蓝底前景（文字/图标） | KD `--hud-text-on-accent` |
| `accent.track` | `rgba(10,108,255,.22)` | — | 进度条已填充段 | 新增 |

> 注：KD 深色主题会把 `blue-6` 提亮到 `#1E74FF`；本设计按设计语言「交互主色 = 品牌蓝 `#0A6CFF`」**覆盖回标准值**，全链路（点击态/焦点态/主按钮）统一取这一支。

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

## 3. 品牌绿 `#00D4AA` 的处置（专节）

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
| **T1** | **品牌绿 `#00D4AA` 处置**：A 完全退出售（推荐）/ B 降级为额度专用色 / C 并入 success | **A** —— 理由见 §3.3 | 关于窗主按钮、页脚额度、周期胶囊；会与现有 `--hud-quota*` 冲突 | 建议阻塞关于窗 + 页脚两屏 |
| **T2** | 面板底色定档：`#0F0F11`（现有）vs KD 深色 `background-base #121212` | 保持 `#0F0F11`。KD 的 `#121212` 偏亮、且带一点中性偏暖，挂在纯黑刘海下会露出色差 | 全部界面基调 | 建议阻塞全部界面 |
| **T3** | 「悬浮层」是否用 `surface.raised = rgba(255,255,255,.06)`（≈`#1D1D1F`，对标 KD `background-group #1F1F1F`） | 采用。但需确认 6% 白在近黑底上是否够可见（实测建议 ≥5%，且必须同时有 `line.divider` 兜底） | 设置窗口导航、面板内次级控件 | 不阻塞骨架 |
| **T4** | **KD 例外登记**：间距 `3/6/10/18`、字号 `8/8.5/9/10.5/11/12.5`、圆角 `14/16` 均不在 KD 刻度上 | **整组登记为「HUD 紧凑刻度 + macOS 原生字号」例外**，以 `hud/*` 命名空间隔离。若用户要求严格贴 KD 刻度，则面板行距会从 3→4、字号 11→12，面板会变胖约 8–10% | 全部几何；改则需重排 | 需要拍板（默认按例外执行） |
| **T5** | **任务灯与 Logo 四态色是否收敛**：现有任务灯 `#8E8E93 / #FFB800 / #FF3B30 / #34C759` vs Logo 四态 `#9CA0AA / #FFC928 / #FF6259 / #31D158` | **收敛为一支**（取 Logo 四态值）。同屏「任务行状态灯 + 顶部 Logo」同时出现两组近义色，是最容易看出「不精致」的地方 | 任务行状态灯、关于窗图例 | 不阻塞骨架 |
| **T6** | 更新红点 `#FF4D4F` 是否并入语义色：与 `status.waiting #FF6259` 存在 2 个红 | 保留 `#FF4D4F`（更饱和、专表「有更新」），但在规范中明确「红点与状态灯不得相邻出现」 | 关于窗更新行、设置入口 | 不阻塞骨架 |
| **T7** | 禁用态是否统一改用 KD 的 `opacity:.4`（而非 `text.disabled` 灰色） | **采用 KD 规则**：交互控件禁用走 `opacity .4`；`text.disabled` 仅用于静态不可用文案。二者并存需用户确认 | 按钮、导航项、输入框 | 不阻塞骨架 |
| **T8** | 深色下**文字对比度自检结论是否接受**：`text.tertiary .55`（`#8E8E8E` on `#0F0F11`）≈ **6.4:1** ✅；`text.quaternary .46`（`#797979`）≈ **4.6:1** ✅（AA 正文临界通过）；`text.disabled .30`（`#545454`）≈ 2.3:1 ❌ 仅限非必要信息 | 接受现状，但**禁止** `text.disabled` 承载任何必要信息（版本号、系统要求等需提到 `tertiary`） | 脚注、空态、关于窗 | 不阻塞骨架 |
| **T9** | 本阶段只出 token 骨架，**界面 HTML 的排期与范围**：刘海收起条 / 主面板 / 任务列表 / 页脚额度 / 空态 / 关于窗 / 设置面板 共 7 面 | 建议顺序：主面板 → 刘海收起条 → 任务列表 → 设置面板 → 关于窗 → 页脚/空态 | 第二阶段范围 | 需要确认 |

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
