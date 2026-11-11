# TMA backend wrappers

框架负责 tmux 布局、状态流转、auto-switch 和 UI；后端差异放在这里。
新增后端只改自己的目录；需要共享逻辑或批量优化时改 `default/`，不往框架添加后端分支。

```text
wrapper/
├── dispatch.sh       # 发现后端、选择函数
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
| `tui_state` | `RECENT_SCREEN` → 无输出，或 `running<TAB>事件来源`；补原生 hook 的事件缺口 |
| `foreground_busy` | `RECENT_SCREEN` → 退出码 0 表示仍在工作，1 表示无工作标记 |
| `install` | 无 → 部署该后端的配置和 hooks |
| `install_cli` | 无 → CLI 未安装时安装 |
| `skills_dir` | 无 → skills 链接路径，默认 `~/.<backend>/skills` |

`session_id`、`fork_command`、`relocate`、`last_message` 等没有通用实现，未实现时明确报不支持。
Gemini 当前具备启动、headless、hooks 和 TUI 状态检测；本次没有增加它的会话 ID 解析、fork、消息提取或迁移恢复能力。

框架还调用以下共享操作：`selected_backend`（读 `TMUX_AI_TOOL`，未设置或空值时为 Codex）、
`session_names PANES...`（输出 `pane<TAB>名称`）、`background_processes PID`、`mark_created WINDOW`，以及
`global_window_name` / `global_window_command` / `livesync_command` / `image_staging_dir` 这些现有工作流的默认配置。
`ai_pane_pids PANE_PIDS` 接收换行分隔的 pane 根 PID，输出含交互式 AI 的根 PID，包含 broker 排除。

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

`default/process.sh` 从目录生成原生进程名匹配规则，同时保留 Gemini 的 node/MainThread 识别。
`_find_ai_pid` 用于单 pane；`ai_pane_pids` 的 Linux 快速路径在 `pane_processes.py` 中，只遍历 pane 子树，遇到 AI 或 broker 就停止该分支。
`_ai_process_snapshot` / `_ai_pane_pid_set` 保留给显式进程快照及非 Linux 路径使用。
`default/session_names.py` 保留原有批量会话名称解析；`mark_created.sh` 和 `background_processes.sh` 也是共享批量路径。
这些文件允许集中写 `codex|claude|gemini` 等判断，避免逐 pane 启动多个解释器。
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
