# Comate Notch HUD 优化 v3

## 项目概述
修复 hover 跳动 + 简化收起态 UI + 设计状态灯+logo 结合方案。

## 核心改动
1. 面板帧锚定刘海顶部不动，展开时仅向下生长
2. 收起态简化为 Comate logo + 状态灯，无文字
3. 状态灯四色：灰(空闲)/黄(运行中)/红(等待/异常)/绿(完成)
4. ComateStore 增加 waiting/error 状态映射

## 实施步骤
1. 重写 NotchPanel：锚定顶部帧计算
2. 重写 NotchRootView：收起态 logo+灯，展开态任务列表
3. 更新 ComateStore：增加状态映射
4. 编译验证