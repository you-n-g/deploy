---
name: watch-target
description: >
  Agentic monitoring for a user-specified target such as a tmux pane, long-running
  command, log, service, training run, or remote job. Use when the user asks to
  watch, monitor, periodically check, supervise, continue/restart when finished,
  or report when a target fails or needs attention. Defaults to a 30 minute
  interval when the user does not specify one.
metadata:
  short-description: 监督目标
---

# `watch-target` — 监督目标

## 触发时机

用户指定一个监控标的，并要求定期查看、继续运行、恢复、汇报异常或等待完成。典型标的包括 tmux pane、训练任务、后台命令、日志文件、服务状态、远程 job。用户没给间隔时默认 30 分钟。

如果用户显式调用本 skill，即使措辞是“capture/read/check 一下”，也按监控任务处理：先立即检查一次，再安排下一次 one-shot 自唤醒。只有用户明确说“只看一次”“不要继续监控”时，才不安排后续唤醒。

## 输入

- **target**：需要监控的对象。应优先根据用户的原话和当下情境来确定，并从上下文推断其完成标准。如果目标尚未完成、未达到标准，则应设法让其继续运行，直到满足要求。
- **interval**：检查间隔，默认 `1800` 秒。
- **policy**：完成、失败、卡住或健康运行时该怎么做。用户没说明时，默认只汇报异常，不打断运行中任务。

只有在 target 或 policy 不清楚且可能导致中断用户任务、重复启动任务或破坏状态时才询问。

## 执行步骤

1. 每次唤醒都重新读取最新状态，不依赖上次结论。
2. 用 Agent 判断状态：仍在运行就不打断；完成且 policy 允许才执行 continue/restart/follow-up；失败、资源不足、认证/额度问题、重复失败或需要人工选择时汇报原因。
3. 除非用户明确要求只检查一次，否则安排下一次 one-shot 唤醒；不要写 `while true`、cron 或固定轮询守护进程。
4. 安排唤醒后立刻验证 timer 确实存在；如果没有成功创建，立即报告，不要假装已经进入监控。

tmux pane 常用检查：

```bash
tmux display-message -p -t '<target-pane>' '#S:#I.#{pane_index} cmd=#{pane_current_command} dead=#{pane_dead} active=#{pane_active} path=#{pane_current_path}'
tmux capture-pane -t '<target-pane>' -p -S -200
```

## 自唤醒

在交互式 Agent pane 中监控时，优先让当前 Agent 自己被 tmux 唤醒，不要额外创建 pane/window，除非用户明确要求。

使用脚本安排下一次唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --pane '<watcher-pane>' \
  --seconds 1800 \
  --message '<下一次唤醒时要提交给 Agent 的检查指令>'
```

脚本会通过 `tmux run-shell -b`、`tmux load-buffer`、`tmux paste-buffer` 和 `tmux send-keys Enter` 提交消息。不要改成 `send-keys ... C-m`，因为 Codex/Claude TUI 中可能只粘贴文本而没有真正提交。

如果这轮是手动触发，安排新 timer 前先检查是否已有自己创建的旧 timer；只清理能确认属于本 watcher 的旧 timer，不要误杀用户其它 sleep/monitor 进程。

安排后用 `ps` 或等价方式确认存在对应的 `sleep <seconds>; tmux ... paste-buffer ... send-keys Enter` 进程，并确认目标 pane、watcher pane 和间隔都匹配本次任务。
