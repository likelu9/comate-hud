# Comate HUD

macOS AI 任务状态灯 — 为 [WPS Comate](https://comate.wps.cn) 而生。

![macOS](https://img.shields.io/badge/macOS-12.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能

- 🟢 **实时状态灯** — 三色状态灯常驻刘海区（绿=空闲 / 黄=工作中 / 等待确认）
- 📋 **任务面板** — 悬停展开，查看最近会话和执行进度
- 🔔 **消息中心** — 铃铛角标动态显示未读消息数
- ⚡ **一键直达** — 点击任务直接打开对应 Comate 会话
- 📊 **额度用量** — 实时显示 AI 用量消耗，支持日/月切换

## 安装

1. 从 [Releases](../../releases) 下载最新 DMG
2. 将 `ComateHUD.app` 拖入「应用程序」文件夹
3. 首次启动请允许辅助功能权限

## 构建

```bash
# 需要 macOS 12.0+ 和 Xcode
cd ComateNotch
./build.sh
```

构建产物：`build/ComateHUD.app`（Universal Binary: arm64 + x86_64）

## 一键发布

```bash
./release.sh <version> <build_num>
# 示例: ./release.sh 1.3.0 4
```

自动完成：构建 DMG → 更新版本清单 → 部署产品介绍页

## 项目结构

```
ComateHUD/              # 产品介绍页（通过 Comate 部署）
├── index.html          # 产品页（动态加载版本信息）
├── versions.json       # 版本清单（版本号 + 下载链接 + 更新日志）
└── icon.png            # 应用图标

ComateNotch/            # macOS 原生应用
├── Sources/
│   ├── ComateHUDApp.swift    # 应用入口
│   ├── ComateStore.swift     # 数据层（SQLite + 云端 API）
│   ├── NotchPanel.swift      # NSPanel 窗口管理
│   ├── NotchRootView.swift   # SwiftUI UI 层
│   ├── SessionJournal.swift  # Comate 日志解析
│   ├── UsageAPI.swift        # 用量 API
│   └── AppDelegate.swift     # App Delegate
├── Resources/          # 图标资源
├── Info.plist          # 应用配置
└── build.sh            # 构建脚本
```

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9+ |
| UI | SwiftUI |
| 窗口 | NSPanel |
| 数据 | SQLite (本地读取 Comate 聊天记录) |
| 网络 | URLSession (云端消息中心 + 用量 API) |
| 集成 | Deeplink (`wpscomate://` 协议) |
| 构建 | Universal Binary (arm64 + x86_64) |

## 兼容性

- macOS 12.0 (Monterey) 或更高版本
- Apple Silicon (M1/M2/M3/M4) & Intel x86_64
- 需安装 WPS Comate 桌面版

## License

MIT
