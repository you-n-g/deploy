# TMA backend wrappers

框架负责 tmux 布局、状态流转、auto-switch 和 UI；后端差异放在这里。
新增后端只改自己的目录；需要共享逻辑或批量优化时改 `default/`，不往框架添加后端分支。

```text
wrapper/
├── dispatch.sh       # 发现后端、选择函数
├── history.sh        # 按 pane 导出后端会话日志
├── default/          # 共享行为、批量进程扫描、会话名称、默认配置
├── codex/            # 启动、会话、fork、消息、hooks
├── claude/
└── gemini/
```

## 调用约定

```bash
source "$TMUX_CONFIG_DIR/wrapper/dispatch.sh"
backend="$(tma_call default selected_backend)"
command="$(tma_call "$backend" launch_command "" "")"
# command 是供 zsh -ic 执行的、已正确引用参数的命令。
```

也可以独立执行：

```bash
bash configs/tmux/wrapper/dispatch.sh --list
bash configs/tmux/wrapper/dispatch.sh gemini launch_command "" ""
```

目录中有 `backend.sh` 就会被发现；后端名使用 `[a-z][a-z0-9_]*`，`default` 为保留名。
函数命名为 `tma_<backend>_<operation>`。dispatcher 先找后端函数，**仅在函数不存在时**找 `tma_default_<operation>`。
函数返回失败时原样传播退出码，不再尝试 default。未知后端/非法操作名返回 64，双方都没有实现的操作返回 69。
函数运行时 `$TMA_BACKEND` 是被调用的后端，`$TMA_WRAPPER_ROOT` 是此目录；后者也可用于测试时指定临时 wrapper 树。
stdout 只放结果，诊断写 stderr。`*_command` 返回命令文本，不执行；用 `tma_quote_command` 引用 argv。

## 接口

| 操作 | 参数 → 输出 / 行为 |
| --- | --- |
| `command` | 无 → CLI/已有 shell 函数名；默认后端名 |
| `launch_command` | `MODEL EFFORT [ARGS...]` → 交互启动命令；空字符串表示未指定；模型在 zsh 加载 rc 后设置 |
| `headless` | `PANE`，stdin 为 prompt → stdout 为答案；共享实现负责临时目录、清理和退出码 |
| `headless_command` | `PANE WORKDIR OUTPUT_FILE` → 读取 stdin、将答案写入文件的命令 |
| `session_id` | `PID PANE` → 当前会话 ID；找不到返回非零 |
| `resume_command` | `SESSION_ID` → 恢复会话命令 |
| `fork_command` | `PID PANE PANE_ROOT_PID` → fork 命令；Codex 在这里保留远程连接参数 |
| `relocate` | `PID PANE` → `cwd<TAB>resume_command`；用于分屏转浮窗，当前只有 Claude 实现 |
| `last_message` | `PANE PID` → 最近完整回答文本；框架负责写入目标文件/复制缓冲区 |
| `history` | `PANE PID [markdown\|jsonl]` → 会话正文 Markdown（默认）或完整原始 JSONL |
| `tui_state` | `RECENT_SCREEN` → 无输出，或 `running<TAB>事件来源`；补原生 hook 的事件缺口 |
| `foreground_busy` | `RECENT_SCREEN` → 退出码 0 表示仍在工作，1 表示无工作标记 |
| `install` | 无 → 部署该后端的配置和 hooks |
| `install_cli` | 无 → CLI 未安装时安装 |
| `skills_dir` | 无 → skills 链接路径，默认 `~/.<backend>/skills` |

`session_id`、`fork_command`、`relocate`、`last_message`、`history` 等没有通用实现，未实现时明确报不支持。
Codex 的 `last_message` 从当前会话日志的 `task_complete.last_agent_message` 读取最近完整回答，
不会发送 Ctrl+O 或等待终端剪贴板确认；新回合的中途说明不会覆盖上一条完整回答。
Gemini 支持启动、headless、hooks、TUI 状态检测、会话 ID 和历史导出；尚未实现 fork、最近回答提取或迁移恢复。
Pi 支持启动、headless、原生事件、会话 ID、恢复、fork、最近回答和历史导出；尚未实现迁移恢复。

## Pi 与网关配置

```bash
bash configs/llm/conf_llm.sh pi
pi
# 在新的 TMA window 中启动；默认模型由本机配置指定，也可显式选择推理强度：
tmuxg --force-new --tool pi --reasoning-effort high
```

要求已安装 `@earendil-works/pi-coding-agent`（验证版本 0.84.3），并已通过 Gemini 配置生成
`~/.gemini/.env` 中的 `GOOGLE_GEMINI_BASE_URL` 和 `GEMINI_API_KEY`。安装器保留 Pi 的其它 provider 和主题，
默认 provider、模型 ID 和显示名称从本机 `~/.config/llm/gateways.local.json` 的 `pi` 对象读取
（`provider`、`model`、`name` 三个字段），默认推理强度设为 `high`。
此文件不在仓库内；例如 `{"pi":{"provider":"google-gateway","model":"model-id","name":"Gateway Model","aliases":["model-alias"]}}`。
凭据通过 Pi 官方 `!command` 机制读取现有文件，不复制进 models.json。
模型参数按 [Gemini Thinking 文档](https://ai.google.dev/gemini-api/docs/thinking)配置为
`contextWindow=1048576`、`maxTokens=65536`，推理选项为 `low` / `medium` / `high`。
1M 是输入、思考和输出共用的窗口。

日常编码任务可使用 `medium`，复杂推理任务使用 `high`；通过推理强度控制思考开销，
避免用过小的输出上限截断思考。当前 Pi 使用流式 GenerateContent，单次输出按 64K 设置。

运行参数建议：保留自动压缩；长任务可将 Pi 的 `compaction.reserveTokens` 设为 `65536`，
为输出留足空间，将 `httpIdleTimeoutMs` 设为 `1200000`（20 分钟），避免长思考被客户端超时打断。
这两项是 Pi 全局设置，安装器保留用户现有值；它们与模型的官方容量参数不同。

Pi 默认自动执行工具；`defaultProjectTrust=always` 让新目录也自动信任项目配置，无需启动确认。
全局 AGENTS.md、共享 skills 和四个扩展（`tma.js`、`gateway.js`、`pull.js`、`prompt.js`）安装到 `~/.pi/agent/`；已有 Pi 会话用 `/reload` 加载扩展，
默认模型用于新会话。`prompt.js` 在输入框上方常驻显示单行截断的最新用户输入（运行中与运行结束后均可见，支持 `/skill:name` 折叠、排队消息切换与 `/tree` 分支同步，`/prompt` 可弹窗查看完整内容或 `toggle` 开关）。`/pull [说明]` 复用原生 `/tree` 选择器与分支摘要接口，将另一条分支相对公共祖先的摘要合并进当前分支而不跳转位置。
`gateway.js` 扩展把 Pi 0.84 的 `thinkingBudget` 转为网关接受的 `thinkingLevel`，
同时支持 `pi.model` 及 `pi.aliases` 模型的聊天、压缩和分支摘要，保留其它模型的原生行为。
同一模型各网关别名切换时保留历史工具调用的 thought signature；只在请求副本中统一模型标识，不改写会话日志。

TMA 扩展只跟踪 tmux 中的交互式 Pi：`before_agent_start` / `agent_start` 标 running，
`agent_settled` 在自动重试、压缩和排队消息都结束后标 idle，手动压缩成功或取消也会结束 running。
它不需要从屏幕文字推断状态，headless Pi 不会改父 pane 的状态。

Pi 支持 `prefix + f` 菜单的窗口、分屏和浮窗 fork：复制当前选中分支的已落盘上下文，
包括工具记录、压缩摘要和模型设置，生成独立会话后启动交互式 Pi。源会话继续保留；
fork 会沿当前 `/tree` 位置复制，不会误选日志末尾的其它分支。

框架还调用以下共享操作：`selected_backend`（读 `TMUX_AI_TOOL`，未设置或空值时为 Codex）、
`session_names PANES...`（输出 `pane<TAB>名称`）、`background_processes PID`、`mark_created WINDOW`，以及
`global_window_name` / `global_window_command` / `livesync_command` / `image_staging_dir` 这些现有工作流的默认配置。
`ai_pane_pids PANE_PIDS` 接收换行分隔的 pane 根 PID，输出含交互式 AI 的根 PID，包含 broker 排除。

## 会话历史导出

```bash
# 不发按键、不打断当前回合；新旧 Codex 界面都可直接使用。
~/deploy/configs/tmux/wrapper/history.sh "$TMUX_PANE" > /tmp/tma-history.md
~/deploy/configs/tmux/wrapper/history.sh 'session:window.0' jsonl > /tmp/tma-history.jsonl
```

入口自动识别 pane 的后端，调用 `history`；支持 Codex、Claude、Gemini 和 Pi。Markdown 只展开会话文字，JSONL 保留工具调用、工具结果、推理及元数据等全部原始记录。输出是执行时已落盘内容的快照，正在生成但尚未写入日志的内容需稍后再次导出。

Codex 复用当前会话 ID 定位，优先读取进程打开的 rollout，保留压缩之前的历史；没有打开文件时按确切会话 ID 在其 Codex 配置目录查找。Claude 复用当前会话/后台 job 的 ID，从 projects 日志中读取。找不到或匹配到多个日志、记录损坏时明确报错，不猜测“最近会话”，也不退回 tmux 屏幕抓取。远程会话的日志需要在保存日志的主机上导出。

Gemini 的原生 hook 将 `session_id`、`transcript_path` 与当前进程 PID/启动时间保存在 pane 的 `@tma_gemini_session` 中。已有窗口在下一次 hook 触发后即可使用，无需重启；尚未收到 hook 时会明确提示。新会话覆盖旧绑定，退出时清除，PID 或启动时间不匹配时报错。Markdown 按 Gemini 的消息 ID、patch、rewind 和排序记录还原当前对话，JSONL 则原样保留回退前后的所有记录。

Pi 扩展在 `@tma_pi_session` 绑定 PID/启动时间、会话 ID、日志路径和当前 leaf。
Markdown 沿当前分支的 parentId 回溯，保留压缩前祖先消息，排除已离开的分支；JSONL 原样保留整棵树。
绑定在消息开始、turn 结束、切分支及会话生命周期事件更新；正在写入的消息在下一个边界后可导出。
新会话尚未落盘时会明确报错，退出或切换会话会清理旧绑定。

此入口不受 alternate screen、tmux history-limit 和 capture 的 `tail` 限制。其它后端只需实现自己的 `tma_<backend>_history`，尚未实现的后端返回 69。

## 新增后端

例如 CLI 名为 `example`，最小的 `example/backend.sh` 可以只有注释：

```bash
# 启动使用 default 的 example 命令；其它能力按需实现。
```

如果需要定制启动参数或接入已有 shell 函数：

```bash
tma_example_command() { printf 'exampler\n'; }
tma_example_launch_command() {
  tma_default_launch_command "$1" "$2" --interactive "${@:3}"
}
```

然后 `tmuxg --force-new --tool example`，或 `tmux set-environment -g TMUX_AI_TOOL example`。
已有后端继续调用 `configs/shell/rcfile.sh` 中的 `codexr` / `clauder` / `geminir`，保持 provider、模型和权限设置。
新的 CLI 可以直接调用，无须在这个 shell 配置中加分支。

接入完整 TMA 状态时，在自己目录实现 hook，并通过 `install` 部署：
启动调用 `script/track_ai_agent_state.sh init PANE`，提交/继续调用 `running`，结束调用 `idle`。
需要记录 prompt 时同时传入 `AI_AGENT_PROMPT`、`AI_AGENT_SESSION_ID`、`AI_AGENT_CWD`、`AI_AGENT_STATE_SOURCE`。
统一 tracker 负责 pending 释放、background 校正和未读状态；后端无需重写这些规则。
原生 hook 覆盖不到的情况才增加 `tui_state`，不要从任意屏幕文本推断 idle。

## 共享快速路径与兼容入口

`default/process.sh` 从目录生成原生进程名匹配规则，同时识别 Gemini 和 Pi 的 node/MainThread 入口。
`_find_ai_pid` 用于单 pane；`ai_pane_pids` 的 Linux 快速路径在 `pane_processes.py` 中，只遍历 pane 子树，遇到 AI 或 broker 就停止该分支。
`_ai_process_snapshot` / `_ai_pane_pid_set` 保留给显式进程快照及非 Linux 路径使用。
`default/session_names.py` 保留原有批量会话名称解析；`mark_created.sh` 和 `background_processes.sh` 也是共享批量路径。
这些文件允许集中写 `codex|claude|gemini|pi` 等判断，避免逐 pane 启动多个解释器。
新后端有特殊进程名、会话格式或祖先进程规则时，在此补充相应识别；框架不变。

旧的 `configs/llm/config_{claude,gemini}.py`、hook JSON、Gemini 指令文档、`ai/session_names.py` 等路径保留软链接；
`script/{claude,gemini}_agent_state_hook.sh` 保留 exec 转发。已运行会话缓存的旧命令仍可工作。
这两个文件仅是升级期的兼容入口，不包含 hook 实现；框架、新配置和常规 hook 测试直接使用 wrapper。
升级前启动的会话全部退出或重新加载 hook 配置后，即可删除这两个入口；单独的兼容测试验证它们仍可转发。
重装 hooks 会同时识别旧/新路径，替换自己的 hook，保留用户自定义 hook 和设置。

## 验证

```bash
python3 -m unittest discover -s configs/tmux/tests -v
```

测试在 `/tmp` 和独立 tmux server 中执行。覆盖后端目录发现、共享实现、错误不 fallback、
参数引用、headless stdin/失败传播、新后端进程识别与框架启动、不支持的迁移不关闭 pane、旧 hook/config 入口和重装幂等性。
