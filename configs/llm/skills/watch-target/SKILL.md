---
name: watch-target
description: >
  Agentic monitoring for a user-specified target such as a tmux pane, long-running
  command, log, service, training run, or remote job. Use when the user asks to
  watch, monitor, periodically check, supervise, continue/restart when finished,
  or report when a target fails or needs attention. Defaults to a 30 minute
  interval when the user does not specify one. When the target is a Codex/Claude
  AI window and the user gave no completion criterion, infer the window's own
  goal from its recent history and keep nudging it until that goal is done.
metadata:
  short-description: 监督目标
---

# `watch-target` — 监督目标

## 触发时机

用户指定一个监控标的，并要求定期查看、继续运行、恢复、汇报异常或等待完成。典型标的包括 tmux pane、训练任务、后台命令、日志文件、服务状态、远程 job。用户没给间隔时默认 30 分钟。

用户只点了一个 AI window、没说要监控它什么时也适用：这种情况下先把那个 window 自己的 goal 读出来，再督促它做完，见「AI window 目标推断与督促」。

如果用户显式调用本 skill，即使措辞是“capture/read/check 一下”，也按监控任务处理：先立即检查一次；只有目标尚未达到用户给定的完成标准、还在运行、或 follow-up 尚未执行完时，才安排下一次 one-shot 自唤醒。若本轮已经完成用户要求的 follow-up（例如 review 通过并已汇报，或发现问题并已把反馈发回目标 pane），不要再安排 30 分钟复查。用户明确说“只看一次”“不要继续监控”时也不安排后续唤醒。

## 输入

- **target**：需要监控的对象。应优先根据用户的原话和当下情境来确定，并从上下文推断其完成标准。如果目标尚未完成、未达到标准，则应设法让其继续运行，直到满足要求。
- **interval**：检查间隔，默认 `1800` 秒。刚启动、重启或恢复的目标先使用 warm-up 短间隔递增复查，稳定后再回到用户给定间隔或默认间隔。
- **policy**：完成、失败、卡住或健康运行时该怎么做。用户没说明时，默认只汇报异常，不打断运行中任务。**例外**：target 是 AI window 且用户没给完成标准时，走「AI window 目标推断与督促」，默认 policy 是把目标自己的 goal 督促到完成。

只有在 target 或 policy 不清楚且可能导致中断用户任务、重复启动任务或破坏状态时才询问。target 是 AI window 时不要反问「你想监控它什么」——它自己在做什么是可以读出来的，见下文。

## 执行步骤

1. 进入监控前先检查**当前 watcher 线程自己**是否处于 active goal 模式（注意区分：这里说的是 watcher 自己的 goal，不是被监控 AI window 的 goal，后者见「AI window 目标推断与督促」）；如果 `get_goal` 可用且返回 `status=active` 的 goal，不要安排 self-wakeup，也不要继续做周期性 watch。active goal 会自动续跑当前 Agent，和 timer watcher 叠加后会变成高频监督，快速消耗 token。此时只做一次必要的轻量状态读取并汇报“监控应等 goal 模式停止后再启动”；等用户停止/完成/阻塞该 goal 后，才重新进入本 skill 的周期监控流程。用户明确要求“忽略 goal 模式继续 watch”时，也必须提醒这会绕过低频间隔并显著增加 token 消耗。
2. 每次唤醒都重新读取最新状态，不依赖上次结论。
3. 用 Agent 判断状态：仍在运行就不打断；完成且 policy 允许才执行 continue/restart/follow-up；失败、资源不足、认证/额度问题、重复失败或需要人工选择时汇报原因。
4. 如果本轮启动、重启或恢复了目标，必须先确认目标确实正常跑起来，再安排睡眠或下一次唤醒。确认方式至少包括重新 capture 元信息和最近输出；如果刚启动时容易短暂报错，就等待一个有界短窗口后复查，看到进程仍活着且没有等待输入、认证失败、配置失败、立即退出等信号，才进入监控睡眠。
5. 对刚启动、重启、恢复，或用户提示“刚起来容易出错”的普通监控目标，下一次唤醒不要直接使用默认 `1800` 秒。先使用 warm-up cadence：`60s -> 120s -> 180s -> 240s -> 480s`；每次健康复查后进入下一个间隔，出现失败/卡住/等待输入就立即诊断处理。完成 warm-up 且目标仍健康运行后，再回到用户给定 interval；如果用户没给 interval，回到默认 `1800` 秒。用户明确指定更短间隔时，以用户指定为上限，不要把 warm-up 调长。
6. 安排 warm-up 唤醒时，把当前阶段和下一阶段写进唤醒消息里，例如 `warm-up 2/5, next interval 120s`，这样下一次被唤醒时能延续递增节奏，而不是丢失状态后直接退回默认间隔。
7. 只有目标未完成或后续动作未完成时，才安排下一次 one-shot 唤醒；不要写 `while true`、cron 或固定轮询守护进程。普通监控目标沿用用户给定 interval 或默认 interval，不要因为可能存在状态信号就擅自改成条件监控。
   如果目标是 Codex/Claude 等 AI window，且当前 `@ai_agent_running=1`，不要使用默认 `1800` 秒 timer；必须使用 AI idle 条件唤醒。目标需要连续 3 次轮询都是 idle 才会唤醒 watcher，避免 goal continuation 在 turn 边界产生的短暂 idle 脉冲误触发；不要为此改变原有轮询间隔。
   如果用户要等待 AI window 从 idle/等待输入状态变成 running（典型是 auto-switch 等用户提交 prompt 后继续调度），不要手写 `while` 轮询；使用 `schedule-wakeup.sh --mode ai-running`，一旦 `@ai_agent_running` 变成 `1` 就立即唤醒 watcher。
   AI 条件唤醒只监听单个目标。需要处理多个候选时，由上层 skill 在唤醒后重新扫描和排序，不要在 wakeup 里塞多目标调度逻辑。
   AI 条件唤醒的另一个终止条件是目标 pane/window 被关闭；目标消失也要唤醒 watcher，让 watcher 重新读取状态并执行后续策略。
8. 如果本轮已经达到终止状态（例如目标 idle、要求的 review/check 已完成、且没有需要发回目标继续改的问题），直接向用户汇报并结束，不要安排 30 分钟复查。在「AI window 目标推断与督促」模式下，目标 idle 本身**不是**终止状态：终止条件以那一节为准。
9. 安排唤醒后立刻验证 timer/condition watcher 确实存在；如果没有成功创建，立即报告，不要假装已经进入监控。

tmux pane 常用检查：

```bash
tmux display-message -p -t '<target-pane>' '#S:#I.#{pane_index} cmd=#{pane_current_command} dead=#{pane_dead} active=#{pane_active} path=#{pane_current_path}'
tmux capture-pane -t '<target-pane>' -p -S -200 | tail -n 80
```

读取 tmux 输出时必须给最终输出再加一层 `tail -n <N>` 硬限制；不要只依赖
`capture-pane -S -200` 这类参数。不同 pane 的 scrollback、wrapped line 或 TUI 内容会让
`-S` 的实际输出远大于预期，导致监控 turn 消耗大量 token。默认只读最近 `80` 行；
需要诊断失败时最多放宽到 `200` 行；只有用户明确要求完整历史时才读取更长输出。

AI Agent tmux pane/window 额外检查：

```bash
tmux display-message -p -t '<target-pane>' 'pane=#{pane_id} window=#{window_id} running=#{@ai_agent_running} unread=#{@ai_agent_unread} attribute=#{@ai_agent_attribute}'
tmux show -pv -t '<target-pane>' @ai_agent_running
```

如果目标是 Codex/Claude 等 AI window，并且 `@ai_agent_running=1`，用户要求的是“等它改完/停下来/完成后继续检查”，不要把默认 interval 当作主要等待机制。应直接使用 tmux AI 状态 attribute 做条件监控：后台观察该 pane 的 `@ai_agent_running`，一旦从 `1` 变为非 `1` 或目标 pane/window 被关闭，就唤醒当前 watcher；`@ai_agent_attribute` 只作为停下后的摘要线索，不作为运行中判断依据。短间隔 sleep 只允许作为条件 watcher 内部的轻量检查，不要变成“固定等 N 分钟再看”的语义。

如果 AI window 当前已经 `@ai_agent_running=0`，不要因为它是 AI window 再安排固定 timer。应立即执行用户指定的 follow-up；follow-up 完成后就结束。固定 `1800` 秒 timer 只用于普通未完成目标，不能作为“已经成功后的复查”。

如果用户的完成标准本身是“目标 AI window 开始运行”，例如等待人类在目标窗口完成响应、让 agent 进入执行态，则 `@ai_agent_running=0` 是需要继续等待的状态。此时用 `ai-running` 条件唤醒，不要立刻结束，也不要退回固定 timer；如果等待期间目标 pane/window 被关闭，也要唤醒 watcher。

## AI window 目标推断与督促

### 触发条件

三条同时满足时进入本模式：

- 用户只点了 target，没说要监控它什么、什么算完成、完成后做什么（典型措辞：「盯着 4 号窗口」「看着它」「监督一下 drafting-baseline」）；
- target 是 Codex/Claude 等 AI window（`@ai_agent_running` / `@ai_agent_attribute` 存在）；
- 用户没有说「只看一次」「只汇报不要打扰它」。

此时默认监控目的就是：**把目标 window 自己正在做的那件事督促到完成**。不要回头问用户「你想让我监控它什么」。

### 1. 先把目标自己的 goal 读出来

这里说的 goal 指「这个窗口当前在奔着做完的那件事」，**跟目标是不是处于 goal 模式无关**。绝大多数被监督的窗口都没开 goal 模式，只是在做用户交代的一件事——那件事就是 goal。不要因为对方没有 goal 模式、没有 `GOAL.md`、没有显式声明目标，就判定「无 goal 可督」而退回普通定时汇报。

按下面的顺序取证，够判断就停，不要把所有来源都跑一遍：

1. 对方如果**确实处于 goal 模式**（capture 里能看到 goal 卡片 / goal 状态行），那份 goal 最权威，直接用，不必再推断。注意 `get_goal` 只能读 watcher 自己的 goal，读不到别的 pane，所以只能从 capture 认。这条是可遇不可求的加分项，不是前置条件。
2. `tmux capture-pane`（默认 80 行，诊断时最多 200 行）。找**用户最近一次给它的指令**，以及它自己列出的 plan / todo / 「下一步」/ 结尾抛出的问题。这是最常用也最强的证据。
3. window 名 + `@ai_agent_attribute`。attribute 是窗口第一次被识别时一次性生成的静态描述，之后不会更新，只能当辅助线索，不能当当前 goal。
4. `#{pane_current_path}` 下的任务文件（`GOAL.md`、`PLAN.md`、`tasks/`、`reports/`）。只在上面几条不足以判断时才读，且只读与 goal 直接相关的部分。
5. 仍判断不了时，直接问目标本人，让它用三行以内回答「当前 goal / 卡在哪 / 还差什么」。**不要猜。**

无论 goal 来自哪一条，都要落成**一句可判定的完成标准**（能回答「什么情况算做完」）。第一次汇报时要把这句话明确告诉用户；如果是推断来的（第 2 条及以后），要说明这是推断的、可以纠正。goal 不是用户给的，用户有权改。

只有一种情况算「读不出 goal」：capture 里没有任何未完成的指令或待办，问它本人也说自己没有在做的事。那就直接汇报「这个窗口目前没有在推进的目标」并结束，不要自己给它编一个目标去督。

### 2. 督促循环

- 目标 `@ai_agent_running=1`：只观察，不发任何消息，用 `--mode ai-idle` 等它停。
- 目标停下来后重新 capture，对照 goal 判断，只有三种走向：
  - **goal 已达成** → 带证据向用户汇报，结束，不再安排唤醒。
  - **未达成，且它是自己停下来的**（做完一段、在等下一步、忘了继续）→ 署名发一条督促消息回目标 pane，说清「goal 是 X，你现在到 Y，还差 Z」，然后用 `--mode ai-running` 等它重新动起来，再切回 `ai-idle`。
  - **未达成，且需要人**（它在问用户问题、认证/额度失败、要用户做技术选择、同一个错误反复出现）→ 不要替用户回答，也不要替它做决定，直接汇报给用户并结束本轮监督。
- 目标 pane/window 消失 → 汇报并结束。

督促消息按 CLAUDE.md 的 TMA 约定发送：`tmux set-buffer` → `paste-buffer` → `sleep 2` → `send-keys Enter`，首行写 `⟦TMA⟧ <发件人> → <收件人>`，两边都是 `<window 名>.<pane 序号>`。

### 3. 终止条件

督促必须有界，不能无限催下去。除了上面三种走向，还有一条硬上限：

- **连续 3 轮督促后，capture 内容相对上一轮没有实质进展**（在原地打转、重复同一段输出、反复失败同一步）→ 停下，把「督了 3 轮没推动」连同证据汇报给用户，不要发第 4 条。

每次汇报和每条唤醒消息里都要带轮次，例如 `督促 2/3`，这样下一次被唤醒时能延续计数，而不是丢状态后从头再督 3 轮。

### 4. 边界

- **只督促，不代做。** 不要在目标 window 里替它写代码、改文件，也不要替它回答它抛给用户的问题。
- 不要修改、扩大或「升级」推断出的 goal。goal 之外的事不归这次监督管。
- 用户点名要监督的这个 window，就是对它 `send-keys` 的明确授权；除此之外的任何 window 都不发。
- 目标正在 running 时不发消息——打断一个正在干活的 agent 比不督促代价更大。

## 自唤醒

在交互式 Agent pane 中监控时，优先让当前 Agent 自己被 tmux 唤醒，不要额外创建 pane/window，除非用户明确要求。

无论是脚本自动唤醒，还是手动通过 tmux 向 Codex/Claude pane 发送唤醒消息，都必须在粘贴文本后等待 2 秒，再发送键盘事件 `Enter`。只 paste 文本不会可靠提交；paste 后立刻 Enter 也可能被 TUI 忽略或只把消息留在输入框里，导致 watcher 看起来“安排了”，但实际没有开始执行。

必须先确定真正的 watcher pane，但不要让调用方同时手填 target 和 watcher 两个 pane，除非确实需要覆盖默认值。`schedule-wakeup.sh` 默认用当前进程的 `$TMUX_PANE` 作为 watcher，这是最可靠的“唤醒自己”来源。不要在 `exec` shell 里用无 `-t` 的 `tmux display-message -p '#S:#I.#{pane_index}'` 来猜“当前 pane”；它可能返回用户当前 active client pane（例如 vim pane），而不是正在执行监控的 Codex/Claude pane。如果 `$TMUX_PANE` 不存在，或需要唤醒另一个 Agent，才显式传 `--pane <watcher-pane>`，并验证 `@ai_agent_attribute` 或 `@ai_agent_running` 非空。

使用脚本安排下一次唤醒：

AI window 目标正在运行时，优先用条件唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --mode ai-idle \
  --target '<target-ai-pane>' \
  --message '<目标停下或关闭后要提交给 watcher 的检查指令>'
```

AI window 目标正在等待输入、而用户要求等它开始运行时，使用反向条件唤醒。这个模式会在目标开始 running 或目标关闭时唤醒 watcher：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --mode ai-running \
  --target '<target-ai-pane>' \
  --message '<目标开始运行或关闭后要提交给 watcher 的检查指令>'
```

只有非 AI 目标，或 AI 目标没有 `@ai_agent_running=1` 这类状态信号时，才用固定间隔唤醒：

```bash
"${CLAUDE_SKILL_DIR}/scripts/schedule-wakeup.sh" \
  --seconds 1800 \
  --message '<下一次唤醒时要提交给 Agent 的检查指令>'
```

脚本将完整 `--message` 保留为本次唤醒的任务文件，只向 composer 发送带 TMA 署名的短文件引用；watcher 收到后先完整读取文件，再执行其中指令。任务文件在提交后仍保留，不能随临时 buffer 一起删除。长文本直接 paste 时，TUI 可能在两次回车之后还没处理完，单纯增加固定等待时间不能保证提交。

短引用通过独立 tmux buffer 和 `paste-buffer -p -d` 发送，显式标记粘贴边界；等待 2 秒，再 `send-keys Enter` 并验证 watcher 开始执行。不要把完整任务重新拼回 composer，也不要在 paste 后立刻 Enter。

`schedule-wakeup.sh` 是唯一唤醒入口，但必须用 `--mode` 把规则分清楚：默认 `timer` 只负责固定时间 one-shot 唤醒；`--mode ai-idle` 轮询单个 AI window 的 `@ai_agent_running`、停下或关闭后立即唤醒；`--mode ai-running` 轮询单个 AI window 的 `@ai_agent_running`、开始运行或关闭后立即唤醒。不要在默认 timer 模式里混入 AI Agent 状态判断，也不要把候选排序、多目标选择、pending 处理塞进 wakeup 脚本；这些属于调用方 skill。

同一个 watcher pane 的 wakeup 是互斥的，只允许有一个 pending wakeup。每次通过 `schedule-wakeup.sh` 安排新唤醒时，脚本会先关闭同一 watcher pane 旧的 `run-wakeup.sh` 进程并清理它的临时 message file，然后再启动新的 watcher。不要绕过 `schedule-wakeup.sh` 手写 `sleep` / 条件循环，否则多个 wakeup 可能互相交替提交消息，造成死锁或重复调度。

安排唤醒应尽量保持静默。不要把 `schedule-wakeup.sh ...` 这类长命令 paste/send 到 watcher pane 里执行，也不要让 watcher TUI 为了安排监控黑屏显示命令执行过程。应从当前 Agent 的 shell/tool 后台调用脚本；脚本默认不输出成功信息，只有调试时才加 `--verbose`。`schedule-wakeup.sh` 只能用 `tmux run-shell -b` 启动一个 detached watcher 后立即返回，不能让 long-lived `run-wakeup.sh` 成为 tmux run-shell job；否则 kill watcher 时 tmux 会在用户终端刷 `terminated by signal ...`。安排完成后的验证用 `ps` / `pgrep` 在后台检查，不要为了展示验证过程打断 watcher pane。

取消自己创建的 watcher 也必须保持静默。`schedule-wakeup.sh` 的后台 job 应在收到 `TERM` / `INT` / `HUP` 时清理临时 message 文件并正常退出，避免 tmux 把整条 `run-shell` command 作为 “terminated by signal ...” 错误刷到用户屏幕上。

自唤醒提交必须验证“消息已提交”，不能只验证“消息已粘贴”。Codex/Claude TUI 处理大段 paste 可能有延迟；无论是 timer 还是 AI idle 条件 watcher，都不要在 `paste-buffer` 后立刻发送最后一个回车。应在 paste 后等待 2 秒，再用单独的 `tmux send-keys -t '<watcher-pane>' Enter` 发送键盘事件；随后检查 watcher pane 的 `@ai_agent_running` 或 capture 内容。如果消息仍停留在输入区（例如只显示 `[Pasted Content ...]` / `› <message>`，且 `@ai_agent_running` 仍为 `0`），再等待 2 秒后补发一次 `Enter`，并重新验证。若验证仍失败，必须明确报告自唤醒没有正常触发。

提交失败时，脚本保留原始任务、发送文本、各阶段 pane/进程/状态快照和命令返回码，日志中的 `diagnostics=` 指向该目录。仍 idle 的 watcher 会清除 background 并标记为提交失败的 pending，避免看起来还在后台监控。

安排新 wakeup 前不需要手动检查旧 timer/condition watcher；统一交给 `schedule-wakeup.sh` 清理同一 watcher pane 的旧 wakeup。不要清理其它 watcher pane 的 sleep/monitor 进程。

安排后用 `ps` 或等价方式确认存在对应的唤醒进程。AI idle / AI running 条件唤醒要确认进程里包含目标 pane 和 watcher pane；固定间隔唤醒要确认进程里包含 watcher pane 和间隔。

对于 AI Agent pane/window，应优先验证条件 watcher 绑定的是目标 pane 的 `@ai_agent_running`，而不是只验证固定 sleep timer。唤醒消息里要要求自己先重新读取目标是否还存在、`@ai_agent_running`、`@ai_agent_pending` 和 capture 内容；如果目标已经关闭，就按用户策略继续（例如寻找下一个需要交互的窗口），不要因为读不到状态而沉默失败。
