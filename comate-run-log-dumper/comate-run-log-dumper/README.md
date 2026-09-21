# Comate 运行过程日志落盘

按任务 `runId` 记录 Comate 运行全生命周期核心链路，并写入用户文档目录：

```text
~/Documents/WPSComate/logs/<runId>.log
```

日志为 JSON Lines 格式，每行一个事件，便于 `tail -f`、检索或后续导入分析。

## 记录内容

| 事件 | 说明 |
|------|------|
| `session_start` | 会话启动/恢复 |
| `run_start` | agent run 开始 |
| `user_message` | provider 请求中的用户消息摘要 |
| `model_request_start` | 模型、provider、上下文估算大小、请求摘要 |
| `model_request_end` | provider 响应状态与 headers |
| `assistant_message` | 模型最终返回消息；过滤 `update`/delta 类大体量流式消息 |
| `turn_end` | 单 turn 结束、stopReason、usage |
| `tool_call` | 工具名、toolCallId、调用参数 |
| `tool_result` | 工具名、toolCallId、是否错误、结果摘要 |
| `context_before_compact` | 上下文压缩前消息数与大小估算 |
| `context_after_compact` | 上下文压缩后消息数与大小估算 |
| `session_shutdown` | 会话关闭 |

## 日志路径

```text
~/Documents/WPSComate/logs/$runid.log
```

如果当前 SDK 事件没有暴露 `runId`，插件会临时写入：

```text
~/Documents/WPSComate/logs/unknown-run.log
```

每行日志会包含 `runIdSource` 字段，用来判断 `runId` 是从事件、context、payload 还是 fallback 得到。

## 构建

```bash
cd /Users/zobor/projects/comate-sdk-demo/comate-run-log-dumper
npm run build
```

## 安装示例

```js
await sdk.plugins.install({
  source: {
    type: 'directory',
    path: '/Users/zobor/projects/comate-sdk-demo/comate-run-log-dumper',
  },
  enabled: true,
})
```

提交任务时选中插件：

```js
plugins: [{ id: 'comate-run-log-dumper' }]
// 或 submit options.pluginRefs: [{ id: 'comate-run-log-dumper' }]
```

## 观察日志

```bash
tail -f ~/Documents/WPSComate/logs/<runId>.log
```

## 数据控制

- 日志会记录工具参数和结果摘要，请勿在不可信环境启用。
- 单段文本/参数/结果做了长度截断，避免 `update` 流式消息和超大工具结果造成日志爆炸。
- 只记录 assistant 的最终消息，不记录 `update`/delta 类型消息。
