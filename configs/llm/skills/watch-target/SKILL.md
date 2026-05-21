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
- **interval**：检查间隔，默认 `1800` 秒。刚启动、重启或恢复的目标先使用 warm-up 短间隔递增复查，稳定后再回到用户给定间隔或默认间隔。
- **policy**：完成、失败、卡住或健康运行时该怎么做。用户没说明时，默认只汇报异常，不打断运行中任务。

只有在 target 或 policy 不清楚且可能导致中断用户任务、重复启动任务或破坏状态时才询问。

## 执行步骤

1. 每次唤醒都重新读取最新状态，不依赖上次结论。
2. 用 Agent 判断状态：仍在运行就不打断；完成且 policy 允许才执行 continue/restart/follow-up；失败、资源不足、认证/额度问题、重复失败或需要人工选择时汇报原因。
3. 如果本轮启动、重启或恢复了目标，必须先确认目标确实正常跑起来，再安排睡眠或下一次唤醒。确认方式至少包括重新 capture 元信息和最近输出；如果刚启动时容易短暂报错，就等待一个有界短窗口后复查，看到进程仍活着且没有等待输入、认证失败、配置失败、立即退出等信号，才进入监控睡眠。
4. 对刚启动、重启、恢复，或用户提示“刚起来容易出错”的普通监控目标，下一次唤醒不要直接使用默认 `1800` 秒。先使用 warm-up cadence：`60s -> 120s -> 180s -> 240s -> 480s`；每次健康复查后进入下一个间隔，出现失败/卡住/等待输入就立即诊断处理。完成 warm-up 且目标仍健康运行后，再回到用户给定 interval；如果用户没给 interval，回到默认 `1800` 秒。用户明确指定更短间隔时，以用户指定为上限，不要把 warm-up 调长。
5. 安排 warm-up 唤醒时，把当前阶段和下一阶段写进唤醒消息里，例如 `warm-up 2/5, next interval 120s`，这样下一次被唤醒时能延续递增节奏，而不是丢失状态后直接退回默认间隔。
6. 只有目标未完成或后续动作未完成时，才安排下一次 one-shot 唤醒；不要写 `while true`、cron 或固定轮询守护进程。普通监控目标沿用用户给定 interval 或默认 interval，不要因为可能存在状态信号就擅自改成条件监控。
   如果目标是 Codex/Claude 等 AI window，且当前 `@ai_agent_running=1`，不要使用默认 `1800` 秒 timer；必须使用 AI idle 条件唤醒，一旦 `@ai_agent_running` 从 `1` 变成非 `1` 就立即唤醒 watcher。
   如果用户要等待 AI window 从普通/idle/等待输入状态变成 running（例如总控切到目标窗口后，等用户提交 prompt 再继续找下一个窗口），不要手写 `while` 轮询；使用 `schedule-wakeup.sh --mode ai-running`，一旦 `@ai_agent_running` 变成 `1` 就立即唤醒 watcher。`ai-running` 还会在 `@ai_agent_pending=1` 时立即唤醒 watcher，让 auto-switch 能跳过这个已被用户标记为 pending 的目标并继续寻找下一个候选。
   AI 条件唤醒支持重复传多个 `--target`；任一目标达到该 mode 的条件或被关闭，都会唤醒 watcher。多目标只用于同一个后续动作确实要被多个目标中的任意一个触发的场景，例如当前只能先处理次优目标，同时等待更符合用户偏好但暂时 running 的 AI 窗口停下。当前目标已经符合用户偏好时，保持单目标 watcher，不要为了“可能更优”而额外挂多目标。
   AI 条件唤醒的另一个终止条件是目标 pane/window 被关闭；目标消失也要唤醒 watcher，让 watcher 重新读取状态并执行后续策略。
7. 如果本轮已经达到终止状态（例如目标 idle、要求的 review/check 已完成、且没有需要发回目标继续改的问题），直接向用户汇报并结束，不要安排 30 分钟复查。
8. 安排唤醒后立刻验证 timer/condition watcher 确实存在；如果没有成功创建，立即报告，不要假装已经进入监控。

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

如果目标是 Codex/Claude 等 AI window，并且 `@ai_agent_running=1`，用户要求的是“等它改完/停下来/完成后继续检查”，不要把默认 interval 当作主要等待机制。应直接使用 tmux AI 状态 attribute 做条件监控：后台观察该 pane 的 `@ai_agent_running`，一旦从 `1` 变为非 `1` 或目标 pane/window 被关闭，就唤醒当前 watcher；`@ai_agent_attribute` 只作为停下后的摘要线索，不作为运行中判断依据。短间隔 sleep 只允许作为条件 watcher 内部的轻量检查，不要变成“固定等 N 分钟再看”的语义。

如果 AI window 当前已经 `@ai_agent_running=0`，不要因为它是 AI window 再安排固定 timer。应立即执行用户指定的 follow-up；follow-up 完成后就结束。固定 `1800` 秒 timer 只用于普通未完成目标，不能作为“已经成功后的复查”。

如果用户的完成标准本身是“目标 AI window 开始运行”，例如等待人类在目标窗口完成响应、让 agent 进入执行态，则 `@ai_agent_running=0` 是需要继续等待的状态。此时用 `ai-running` 条件唤醒，不要立刻结束，也不要退回固定 timer；如果等待期间目标 pane/window 被关闭，也要唤醒 watcher。

如果有多个 AI window 都能触发同一个后续动作，不要创建多个含义相同的 watcher；对 `schedule-wakeup.sh` 重复传 `--target`。`ai-idle` 表示任一目标停下或关闭后唤醒，`ai-running` 表示任一目标开始 running、变成 pending 或关闭后唤醒。只有当前选择是次优、且确实存在更符合用户偏好的暂不可切目标时，才把它们一起监听；当前选择已经符合用户偏好时，使用单目标 watcher。不同语义仍然拆成不同 mode，不要把“等 running”和“等 idle”混在同一个 timer 里。

## 自唤醒

在交互式 Agent pane 中监控时，优先让当前 Agent 自己被 tmux 唤醒，不要额外创建 pane/window，除非用户明确要求。

无论是脚本自动唤醒，还是手动通过 tmux 向 Codex/Claude pane 发送唤醒消息，都必须在粘贴文本后发送键盘事件 `Enter`。只 paste 文本不会可靠提交；消息可能停在输入框里，导致 watcher 看起来“安排了”，但实际没有开始执行。

必须先确定真正的 watcher pane，但不要让调用方同时手填 target 和 watcher 两个 pane，除非确实需要覆盖默认值。`schedule-wakeup.sh` 默认用当前进程的 `$TMUX_PANE` 作为 watcher，这是最可靠的“唤醒自己”来源。不要在 `exec` shell 里用无 `-t` 的 `tmux display-message -p '#S:#I.#{pane_index}'` 来猜“当前 pane”；它可能返回用户当前 active client pane（例如 vim pane），而不是正在执行监控的 Codex/Claude pane。如果 `$TMUX_PANE` 不存在，或需要唤醒另一个 Agent，才显式传 `--pane <watcher-pane>`，并验证 `@ai_agent_attribute` 或 `@ai_agent_running` 非空。

使用脚本安排下一次唤醒：

AI window 目标正在运行时，优先用条件唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --mode ai-idle \
  --target '<target-ai-pane>' \
  --message '<目标停下或关闭后要提交给 watcher 的检查指令>'
```

AI window 目标正在等待输入、而用户要求等它开始运行时，使用反向条件唤醒。这个模式会在目标开始 running、目标被标记为 pending、或目标关闭时唤醒 watcher：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --mode ai-running \
  --target '<target-ai-pane>' \
  --message '<目标开始运行、变成 pending 或关闭后要提交给 watcher 的检查指令>'
```

如果多个 AI window 任意一个满足条件都应该唤醒，重复传 `--target`：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --mode ai-running \
  --target '<current-ai-pane>' \
  --target '<preferred-ai-pane>' \
  --message '<任一目标开始运行、变成 pending 或关闭后，重新读取这些目标并继续调度>'
```

只有非 AI 目标，或 AI 目标没有 `@ai_agent_running=1` 这类状态信号时，才用固定间隔唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --seconds 1800 \
  --message '<下一次唤醒时要提交给 Agent 的检查指令>'
```

脚本会通过 `tmux run-shell -b`、`tmux load-buffer`、`tmux paste-buffer` 和 `tmux send-keys Enter` 提交消息。最后一步必须是键盘事件 `Enter`，并且要验证消息确实触发了 watcher；不要改成只 `paste-buffer`，也不要改成 `send-keys ... C-m`，因为 Codex/Claude TUI 中可能只把文本留在输入框里，没有真正提交。

`schedule-wakeup.sh` 是唯一唤醒入口，但必须用 `--mode` 把规则分清楚：默认 `timer` 只负责固定时间 one-shot 唤醒；`--mode ai-idle` 轮询 AI window 的 `@ai_agent_running`、停下或关闭后立即唤醒；`--mode ai-running` 轮询 `@ai_agent_running` 和 `@ai_agent_pending`，目标开始运行、变成 pending 或关闭后立即唤醒。不要在默认 timer 模式里混入 AI Agent 状态判断。

安排唤醒应尽量保持静默。不要把 `schedule-wakeup.sh ...` 这类长命令 paste/send 到 watcher pane 里执行，也不要让 watcher TUI 为了安排监控黑屏显示命令执行过程。应从当前 Agent 的 shell/tool 后台调用脚本；脚本默认不输出成功信息，只有调试时才加 `--verbose`。`schedule-wakeup.sh` 只能用 `tmux run-shell -b` 启动一个 detached watcher 后立即返回，不能让 long-lived `run-wakeup.sh` 成为 tmux run-shell job；否则 kill watcher 时 tmux 会在用户终端刷 `terminated by signal ...`。安排完成后的验证用 `ps` / `pgrep` 在后台检查，不要为了展示验证过程打断 watcher pane。

取消自己创建的 watcher 也必须保持静默。`schedule-wakeup.sh` 的后台 job 应在收到 `TERM` / `INT` / `HUP` 时清理临时 message 文件并正常退出，避免 tmux 把整条 `run-shell` command 作为 “terminated by signal ...” 错误刷到用户屏幕上。

自唤醒提交必须验证“消息已提交”，不能只验证“消息已粘贴”。Codex/Claude TUI 处理大段 paste 可能有延迟；无论是 timer 还是 AI idle 条件 watcher，都不要在 `paste-buffer` 后立刻发送最后一个回车。应在 paste 后短暂等待，再用单独的 `tmux send-keys -t '<watcher-pane>' Enter` 发送键盘事件；随后检查 watcher pane 的 `@ai_agent_running` 或 capture 内容。如果消息仍停留在输入区（例如只显示 `[Pasted Content ...]` / `› <message>`，且 `@ai_agent_running` 仍为 `0`），再补发一次 `Enter`，并重新验证。若验证仍失败，必须明确报告自唤醒没有正常触发。

如果这轮是手动触发，安排新 timer 前先检查是否已有自己创建的旧 timer；只清理能确认属于本 watcher 的旧 timer，不要误杀用户其它 sleep/monitor 进程。

安排后用 `ps` 或等价方式确认存在对应的唤醒进程。AI idle 条件唤醒要确认进程里包含 `watch-target-wakeup-ai-idle` 标记、目标 pane 列表和 watcher pane；AI running 条件唤醒要确认进程里包含 `watch-target-wakeup-ai-running` 标记、目标 pane 列表和 watcher pane，并知道它会同时监听 running、pending 和关闭；固定间隔唤醒要确认进程里包含 `watch-target-wakeup-timer` 标记、watcher pane 和间隔。

对于 AI Agent pane/window，应优先验证条件 watcher 绑定的是目标 pane 的 `@ai_agent_running`，而不是只验证固定 sleep timer。唤醒消息里要要求自己先重新读取目标是否还存在、`@ai_agent_running`、`@ai_agent_pending` 和 capture 内容；如果目标已经关闭，就按用户策略继续（例如寻找下一个需要交互的窗口），不要因为读不到状态而沉默失败。
