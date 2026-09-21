# Todos — usage-credits

1. [x] UsageAPI.swift：两个接口客户端 + 限额/明细模型 + UTC+8 归日工具
2. [-] 凭据与降级：keychain sid 复用、未登录/失效退避，核对 credential_wps 条目命名与多账号场景
3. [ ] ComateStore：usage 状态、60s 限额 + 5min 回填、把 30 天智点写进 ComateTask
4. [ ] 行内统一显示近 30 天智点（无记录 → 占位符）
5. [ ] 左下角限额百分比 + 日/月切换 + UserDefaults 持久化
6. [ ] 逻辑单测：归日、30 天聚合、占位符、切换持久化、降级分支
7. [ ] 实拍验证 + 坏 sid/断网降级验证
