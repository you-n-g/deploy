# 用户全局 Claude Code 偏好

## 编码原则

- **不要过度防御性编程。** 只在系统边界（用户输入、外部 API、跨进程 IO）做校验；内部函数之间互相信任，不要重复检查框架/语言已经保证的东西。
- **Retry 可以加，过度 fallback 不要加。** Retry 是针对瞬时故障（网络抖动、限流、临时锁）的防错机制，该加就加——但达到上限后应该抛错，不要悄悄降级到另一条代码路径。**过度兜底**（用户没要求的 fallback 分支、silent-skip、用默认值糊过未预期的情况）一律不加：这类 fallback 会让 bug 被掩埋，我宁可看到明确的 error。
- **失败要响亮。** 当前置条件不满足、配置缺失、依赖不可用时，立刻 `raise` / `exit 1` 并带清晰的错误信息，不要用默认值糊过去。
- **不要 try/except 吞异常。** 除非明确知道要处理哪一类异常并且有明确的恢复策略（retry、资源清理、转换为领域异常），否则让异常向上传播。`except Exception: pass` 和 `except Exception: log.warning(...)` 都是反模式。

## 我是谁
我是 xiao / xiaoyang  
如果在提交代码或处理内容时需要确认我的身份，请参考这里。


## 我的 Tmux Multi-Agent 系统(简称TMA)

TMA 是我的日常协作工具和任务组织方式，不是我的研究方向。讨论论文、研究判断、技术路线或对外交流时，不要把 TMA 当作研究主题、研究贡献或个人方向来展开；只有在用户明确要求讨论我的工作流、工具链、agent 协作机制或 skill 落地方式时，才把 TMA 作为工具背景提到。

我平时会用 multi-agent system 来完成复杂任务。对我来说，每个 Agent 都类似一个独立的 Claude 或 Codex session，并对应 tmux session 里的一个 window。服务于同一任务的一组 Agent 通常会放在同一个 tmux session 中，其中一个 tmux window 会作为 orchestrator Agent，负责协调、分派和汇总。

这套组织方式的好处是，Agent 之间可以直接通过 tmux 命令通信：例如读取另一个 window 中某个 Agent 的完整历史，或者用 `send-keys` 向其他 Agent 发送消息。基于 tmux 的这种管理方式，我可以很方便地搭建、调整和观察各种 agent system，也更容易让人随时加入互动或进行干预。

当我有一些重复任务时，我倾向于把它包装成一个 multi-agent system。对于我在 skill 中描述或沉淀下来的 multi-agent system，你可以尽量基于这套 tmux + Agent 的机制来实现，而不是重新发明另一套协作方式。

在实际使用时，我会把运行在某个 tmux window 中的 codex 或 claude 代码实例直接称为一个 TMA Agent。

### TMA Agent 创建与通信约定

当一个 skill 需要创建多个协作 Agent 时，优先使用这套共享 TMA 机制。具体 skill 只需要描述角色、任务边界和最终产物，不需要重复发明 Agent 创建和通信方式。

#### 基本角色

- **orchestrator TMA Agent**：调用 skill 的当前 Agent，通常运行在当前 tmux session 的 `orchestrator` window 中，负责创建、分派、调度、观察和汇总其它 TMA Agent。
- **worker / analysis TMA Agent**：由 orchestrator 创建的协作 Agent，运行在同一个 tmux session 的独立 window 中，负责一个明确的子任务。

#### 创建 TMA Agent

新建的 TMA Agent 默认应该是交互式的 Codex / Claude Code 会话，方便用户随时切到对应 window 继续协作。启动命令使用我定制过参数的封装：

- Codex: `codexr`
- Claude Code: `clauder`

优先给每个 TMA Agent 创建独立 tmux window，window 名要表达任务语义：

```bash
CURRENT_SESSION="$(tmux display-message -p '#S')"
REPO_ROOT="$(git rev-parse --show-toplevel)"
AGENT_WINDOW="analysis-<short-task-name>"

tmux new-window -t "$CURRENT_SESSION:" -n "$AGENT_WINDOW" -c "$REPO_ROOT"
TARGET="$CURRENT_SESSION:$AGENT_WINDOW.0"
tmux send-keys -t "$TARGET" 'codexr' C-m
# 或：
tmux send-keys -t "$TARGET" 'clauder' C-m
```

如果任务明确要求在当前 window 内并排观察，也可以用 pane，但默认还是 window：

```bash
tmux split-window -t "$CURRENT_SESSION:" -c "$REPO_ROOT"
TARGET="$(tmux display-message -p '#{pane_id}')"
tmux send-keys -t "$TARGET" 'codexr' C-m
```

不要使用一次性/headless 模式；不要让 Agent 运行完任务后自动退出。TMA 的价值之一是用户可以随时加入某个 window 互动。

#### 向 TMA Agent 发送任务

多行任务说明用 tmux buffer/paste，比逐行 `send-keys` 稳定：

```bash
PROMPT_TEXT="你是 <role> TMA Agent。

任务：
1. <明确子任务>
2. <边界>
3. <输出格式>

约束：
- 只处理分配给你的范围。
- 不要修改无关文件。
- 不要中断运行中的任务。
- 不要执行 git push。"

tmux set-buffer -b tma-agent-prompt "$PROMPT_TEXT"
tmux paste-buffer -b tma-agent-prompt -t "$TARGET"
tmux send-keys -t "$TARGET" C-m
```

只向 orchestrator 自己创建的协作 window/pane 发送输入。不要向已有业务运行 window、训练 window、用户正在操作的 window 发送 `send-keys`，除非用户明确要求。

#### 读取 TMA Agent 状态

orchestrator 通过 tmux capture 观察其它 Agent：

```bash
tmux capture-pane -t "$TARGET" -p -S -3000
tmux list-windows -t "$CURRENT_SESSION" -F '#S:#I #W active=#{window_active}'
tmux list-panes -t "$CURRENT_SESSION" -a -F '#S:#I.#{pane_index} #{window_name} #{pane_current_path} #{pane_current_command}'
```

window 名称是重要语义来源，应在报告和调度记录中保留。需要等待多个 Agent 完成时，orchestrator 可以周期性 capture 它们的输出，而不是要求它们写到同一个共享文件。

#### 任务分派原则

- 每个 TMA Agent 的任务要边界清楚，最好只负责一个 workspace、一个模块、一个问题或一个报告片段。
- orchestrator TMA Agent 负责全局调度和最终汇总，避免自己深入所有细节。orchestrator 也可以鼓励其他 TMA Agent 互相沟通，协作。
- worker / analysis TMA Agent 只处理自己的范围，不顺手修改或分析其它范围。
- 如果某个 skill 需要长期沉淀，应把“角色分工、任务模板、输出格式”写进 skill，把“如何创建和通信”引用本节即可。
