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

如果用户显式调用本 skill，即使措辞是“capture/read/check 一下”，也按监控任务处理：先立即检查一次；只有目标尚未达到用户给定的完成标准、还在运行、或 follow-up 尚未执行完时，才安排下一次 one-shot 自唤醒。若本轮已经完成用户要求的 follow-up（例如 review 通过并已汇报，或发现问题并已把反馈发回目标 pane），不要再安排 30 分钟复查。用户明确说“只看一次”“不要继续监控”时也不安排后续唤醒。

## 输入

- **target**：需要监控的对象。应优先根据用户的原话和当下情境来确定，并从上下文推断其完成标准。如果目标尚未完成、未达到标准，则应设法让其继续运行，直到满足要求。
- **interval**：检查间隔，默认 `1800` 秒。
- **policy**：完成、失败、卡住或健康运行时该怎么做。用户没说明时，默认只汇报异常，不打断运行中任务。

只有在 target 或 policy 不清楚且可能导致中断用户任务、重复启动任务或破坏状态时才询问。

## 执行步骤

1. 每次唤醒都重新读取最新状态，不依赖上次结论。
2. 用 Agent 判断状态：仍在运行就不打断；完成且 policy 允许才执行 continue/restart/follow-up；失败、资源不足、认证/额度问题、重复失败或需要人工选择时汇报原因。
3. 只有目标未完成或后续动作未完成时，才安排下一次 one-shot 唤醒；不要写 `while true`、cron 或固定轮询守护进程。普通监控目标沿用用户给定 interval 或默认 interval，不要因为可能存在状态信号就擅自改成条件监控。
   如果目标是 Codex/Claude 等 AI window，且当前 `@ai_agent_running=1`，不要使用默认 `1800` 秒 timer；必须使用 AI idle 条件唤醒，一旦 `@ai_agent_running` 从 `1` 变成非 `1` 就立即唤醒 watcher。
4. 如果本轮已经达到终止状态（例如目标 idle、要求的 review/check 已完成、且没有需要发回目标继续改的问题），直接向用户汇报并结束，不要安排 30 分钟复查。
5. 安排唤醒后立刻验证 timer/condition watcher 确实存在；如果没有成功创建，立即报告，不要假装已经进入监控。

tmux pane 常用检查：

```bash
tmux display-message -p -t '<target-pane>' '#S:#I.#{pane_index} cmd=#{pane_current_command} dead=#{pane_dead} active=#{pane_active} path=#{pane_current_path}'
tmux capture-pane -t '<target-pane>' -p -S -200
```

AI Agent tmux pane/window 额外检查：

```bash
tmux display-message -p -t '<target-pane>' 'pane=#{pane_id} window=#{window_id} running=#{@ai_agent_running} unread=#{@ai_agent_unread} attribute=#{@ai_agent_attribute}'
tmux show -pv -t '<target-pane>' @ai_agent_running
```

如果目标是 Codex/Claude 等 AI window，并且 `@ai_agent_running=1`，用户要求的是“等它改完/停下来/完成后继续检查”，不要把默认 interval 当作主要等待机制。应直接使用 tmux AI 状态 attribute 做条件监控：后台观察该 pane 的 `@ai_agent_running`，一旦从 `1` 变为非 `1` 就唤醒当前 watcher；`@ai_agent_attribute` 只作为停下后的摘要线索，不作为运行中判断依据。短间隔 sleep 只允许作为条件 watcher 内部的轻量检查，不要变成“固定等 N 分钟再看”的语义。

如果 AI window 当前已经 `@ai_agent_running=0`，不要因为它是 AI window 再安排固定 timer。应立即执行用户指定的 follow-up；follow-up 完成后就结束。固定 `1800` 秒 timer 只用于普通未完成目标，不能作为“已经成功后的复查”。

## 自唤醒

在交互式 Agent pane 中监控时，优先让当前 Agent 自己被 tmux 唤醒，不要额外创建 pane/window，除非用户明确要求。

必须先确定真正的 watcher pane，但不要让调用方同时手填 target 和 watcher 两个 pane，除非确实需要覆盖默认值。`schedule-wakeup.sh` 默认用当前进程的 `$TMUX_PANE` 作为 watcher，这是最可靠的“唤醒自己”来源。不要在 `exec` shell 里用无 `-t` 的 `tmux display-message -p '#S:#I.#{pane_index}'` 来猜“当前 pane”；它可能返回用户当前 active client pane（例如 vim pane），而不是正在执行监控的 Codex/Claude pane。如果 `$TMUX_PANE` 不存在，或需要唤醒另一个 Agent，才显式传 `--pane <watcher-pane>`，并验证 `@ai_agent_attribute` 或 `@ai_agent_running` 非空。

使用脚本安排下一次唤醒：

AI window 目标正在运行时，优先用条件唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --mode ai-idle \
  --target '<target-ai-pane>' \
  --message '<目标停下后要提交给 watcher 的检查指令>'
```

只有非 AI 目标，或 AI 目标没有 `@ai_agent_running=1` 这类状态信号时，才用固定间隔唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --seconds 1800 \
  --message '<下一次唤醒时要提交给 Agent 的检查指令>'
```

脚本会通过 `tmux run-shell -b`、`tmux load-buffer`、`tmux paste-buffer` 和 `tmux send-keys Enter` 提交消息。不要改成 `send-keys ... C-m`，因为 Codex/Claude TUI 中可能只粘贴文本而没有真正提交。

`schedule-wakeup.sh` 是唯一唤醒入口，但必须用 `--mode` 把规则分清楚：默认 `timer` 只负责固定时间 one-shot 唤醒；`--mode ai-idle` 才轮询 AI window 的 `@ai_agent_running`、停下后立即唤醒，并在必要时补发 Enter。不要在默认 timer 模式里混入 AI Agent 状态判断。

安排唤醒应尽量保持静默。不要把 `schedule-wakeup.sh ...` 这类长命令 paste/send 到 watcher pane 里执行，也不要让 watcher TUI 为了安排监控黑屏显示命令执行过程。应从当前 Agent 的 shell/tool 后台调用脚本；脚本默认不输出成功信息，只有调试时才加 `--verbose`。安排完成后的验证用 `ps` / `pgrep` 在后台检查，不要为了展示验证过程打断 watcher pane。

自唤醒提交必须验证“消息已提交”，不能只验证“消息已粘贴”。Codex/Claude TUI 处理大段 paste 可能有延迟；如果手写 AI idle 条件 watcher，不要在 `paste-buffer` 后立刻发送最后一个回车。应在 paste 后短暂等待，再用单独的 `tmux send-keys -t '<watcher-pane>' Enter` 发送键盘事件；随后检查 watcher pane 的 `@ai_agent_running` 或 capture 内容。如果消息仍停留在输入区（例如只显示 `[Pasted Content ...]` / `› <message>`，且 `@ai_agent_running` 仍为 `0`），再补发一次 `Enter`，并重新验证。

如果这轮是手动触发，安排新 timer 前先检查是否已有自己创建的旧 timer；只清理能确认属于本 watcher 的旧 timer，不要误杀用户其它 sleep/monitor 进程。

安排后用 `ps` 或等价方式确认存在对应的唤醒进程。AI idle 条件唤醒要确认进程里包含 `watch-target-wakeup-ai-idle` 标记、目标 pane 和 watcher pane；固定间隔唤醒要确认进程里包含 `watch-target-wakeup-timer` 标记、watcher pane 和间隔。

对于 AI Agent pane/window，应优先验证条件 watcher 绑定的是目标 pane 的 `@ai_agent_running`，而不是只验证固定 sleep timer。唤醒消息里要要求自己先重新读取 `@ai_agent_running` 和 capture 内容，再判断是否需要执行用户指定的 follow-up（例如 code review、督促继续改、重启等）。
