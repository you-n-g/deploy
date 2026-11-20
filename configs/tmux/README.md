# Backend wrappers

后端差异统一放在 [`wrapper/`](wrapper/README.md)：`codex/`、`claude/`、`gemini/` 各自实现接口，缺少实现时使用 `default/`；执行失败直接报错。共享批量扫描和必要的后端硬编码也放在 `default/`。新增后端无需修改布局、状态管理和 auto-switch 框架，接口与扩展方法见该说明。

`prefix + C-g` 的全局选择器先打开界面，再异步装入实时列表；加载途中可以输入搜索词或取消。默认光标落在列表中第一条未读，没有未读时选第一条空闲 pane；只有一个候选时直接选中，没有候选时返回。pane 状态标记一次批量读取，由 `ai/pane_list.awk` 统一渲染。

# 访问历史

- `prefix + Ctrl-h` 或 `prefix + Ctrl-[`：回到上一次访问的位置。
- `prefix + Ctrl-l` 或 `prefix + Ctrl-]`：沿历史前进。
- Termux 可以用 `Ctrl-h` 和 `Ctrl-l`。按一次 prefix 后，可以交替连按后退键和前进键。
  每次按键都会重新开始 2 秒连按计时；两次按键的最大间隔由 `repeat-time` 控制。
  这是 tmux 通用设置，也适用于方向键等其它可连按绑定。
- `Esc` 取消 prefix 或连按等待，不触发历史跳转。
- 原来的 `prefix + [`（复制模式）和 `prefix + ]`（粘贴）保留。

每个连接中的 tmux client 分别记录最近 9 个 pane 访问位置，包含当前位置，
可以跨 window/session。连续访问同一个位置不会重复记录。
例如 `A → B → C`，后退到 B 再访问 D，历史变成 `A → B → D`。
关闭的 pane 会跳过；窗口改名、重编号不影响历史。

状态栏机器人图标前显示「当前位置/轨迹长度」，适用于所有 pane，从 1 开始计数。
满 9 个位置时省略分母 `/9`，例如 `7/9` 显示 `7`，`9/9` 显示 `9`。
未满时统一显示 `3/5`、`4/7` 这样的数字，不使用单字符分数，也不约分。
数字旁的绿色 `…` 表示正在等待下一次按键，例如 `7…`。
连按超时或按 Esc 后标记消失；仅按下 prefix、尚未输入快捷键时也会显示标记，
此时遵循 tmux 原有的 prefix 等待行为，不是两秒倒计时。

`Ctrl-[` 和 `Esc` 在传统终端编码中相同。`tmux.conf` 为 xterm-256color
开启扩展按键与焦点事件，并请求 xterm modifyOtherKeys / Kitty 消歧模式；VS Code 使用后者。
VS Code Remote-SSH 重连或 Reload Window 时，远端 `ptyHost` 保持 `tmux attach` 不断开，但 `@xterm/addon-serialize` 重放屏幕状态时会丢掉 Kitty 键盘协议标记 `\e[=1u`，因此 `script/ensure_extkeys.sh` 会在 `source-file`、`client-focus-in` 和 `client-resized` 时对已连接的 `xterm-256color` 客户端重新下发 `\e[>4;2m\e[=1u`，无需手动重新 attach。
VS Code 的 `terminal.integrated.enableKittyKeyboardProtocol` 需要为 `true`（当前版本默认开启）。
不支持这些协议的终端无法区分这两个键，`Ctrl-[` 会被识别成取消等待的 `Esc`。
tmux 3.7b 不能直接解析 Kitty 的短 Esc 编码 `ESC [ 27 u`，因此配置保留
`User900` 接收完整编码：prefix 中取消等待，普通 pane 中发送真正的 Esc，避免残留 `27u`。

只记录 client 实际显示的位置，在后台窗口选择 pane 不会加入历史。
同一个 session 的活动 window/pane 是 tmux 共享状态，因此切换仍可能影响
连接到该 session 的其它 client，但它们的历史游标分别维护。
历史存在 tmux 内存中，从加载配置时开始；断开 client 后清除，不随工作区导出。

上限由 `jump-history.conf` 中的 `@jump-history-limit` 设置（2～9）。
本机可以在 `~/.tmux.conf` 的 `source-file` 后覆盖：

```tmux
set -g @jump-history-limit 9
```

回归检查使用独立的临时 tmux server：

```sh
python3 -m unittest discover -s configs/tmux/tests -v
```

# TMA 会话历史

[`wrapper/history.sh`](wrapper/README.md#会话历史导出) 支持 Codex、Claude、Gemini，按 pane 定位后端保存的会话日志，可导出 Markdown 对话或完整 JSONL。它不依赖 tmux scrollback，也不需要关闭 Agent 的滚动界面：

```sh
~/deploy/configs/tmux/wrapper/history.sh "$TMUX_PANE" > /tmp/tma-history.md
~/deploy/configs/tmux/wrapper/history.sh 'session:window.0' jsonl > /tmp/tma-history.jsonl
```

# 浮窗与 zoom

选中浮窗后，`prefix + Ctrl-W` 打开位置菜单；菜单保持显示，接下来可以连续按键：

| 按键 | 行为 |
| --- | --- |
| `h` / `l` | 左／右半屏；与上／下组合为角落；在同侧角落重复该键，展开为半屏 |
| `k` / `j` | 上／下半屏；与左／右组合为角落；在同侧角落重复该键，展开为半屏 |
| `c` | 保持尺寸居中，过大时缩小到窗口内；清除方向组合 |
| `C`（Shift+C） | 尽量保持尺寸和位置，将浮窗移回当前窗口内，过大时才缩小；清除方向组合 |
| `Esc` / `Enter` / `q` | 关闭菜单，恢复向浮窗程序输入 |

例如打开菜单后按 `h k` 停靠左上角，再按 `l` 改为右上角，再按一次 `l` 展开为右半屏。菜单持续到退出，
不需要反复按 prefix；重新按 `prefix Ctrl-W` 会重新开始方向组合；鼠标点击其它窗格或切走焦点时，菜单浮窗会自动关闭并保留焦点在新选中的位置。
浮窗边框计入可用区域。实现由 `float-position.conf` 和 `script/float_position.py` 提供。

这项功能使用官方 tmux 3.8 的 `move-pane` / `resize-pane` 接口，无需补丁。
用 `module add tmux-3.8` 加载后，需要重启 server 才能升级；仅重新加载配置无效。
`prefix + j → f` / `V` / `S` 直接使用原生 `break-pane -W`、`move-pane -P top-right` 和 `join-pane` 在浮窗与分屏之间互转，保留进程、pane ID 和 Agent 会话。

通过 `codexr` / `clauder` 启动的 TMA 及 Pi、DSH 中，`Ctrl+G` 在窗口底部、水平居中的小浮窗里用 Vim 编辑输入，最大 100 列 × 20 行。普通模式按 `q` 或用 `:wq` 保存退出，内容回到原输入框；`:q!` 放弃未保存的修改。编辑期间调用方会等待，关闭浮窗也会结束等待。当前会话下次按 `Ctrl+G`（Pi 已运行会话执行一次 `/reload`，DSH 已运行会话重开一次 `dsh-tui --continue`）即使用新入口。

tmux 3.7b 有个 bug：在 zoom 状态的 window 里用 `new-pane` 建的 floating pane，之后无论是进程退出、`kill-pane`，还是取消 zoom 后再关闭，server 都会在 `layout_destroy_cell` 里段错误退出，所有 session 一起没了。先建浮窗再 zoom 不会触发。

所有浮窗都经 `script/new_float_pane.sh` 创建，它是唯一调用 `tmux new-pane` 的地方（`tests/test_float_panes.py` 会拒绝别处的直接调用）：默认先取消 zoom 再建；后台弹出的不打断 zoom：`--skip-if-zoomed` 时不建、退出码 3（auto-switch 切换预览）；`--zoomed-message TEXT` 同样不建，但先在状态栏显示 TEXT 5 秒（完成 toast）。tmux 修复前不要绕过它。

另一个坑：window 处于 zoom 时，tmux 把浮窗的 `#{pane_floating_flag}` 报成 0。按这个标志区分浮窗和分屏的地方（如 `prefix + j → f / V / S`、`float_position.py`）都先取消 zoom 再判断。

# AI pane 状态标识

Gemini CLI 通过 `bash ~/deploy/configs/llm/conf_llm.sh gemini` 安装 TMA hooks，重新启动 `geminir` 后生效。`BeforeAgent` 标记运行并记录 prompt，`BeforeModel` / `BeforeTool` / `PreCompress` 补充恢复运行，`AfterAgent` 标记空闲/未读，工具审批通知让 pane 回到可切入状态。事件统一交给 `track_ai_agent_state.sh`，沿用 auto-switch、pending 依赖释放和 watcher 的 background 校正。`geminir` 同时启动已有的 TUI tracker，处理取消或异常后没有结束 hook 的情况。

单独新建 Gemini 窗口可用 `tmuxg --force-new --tool gemini`；若希望 `prefix + c` 等新建入口默认使用 Gemini，执行 `tmux set-environment -g TMUX_AI_TOOL gemini`。Linux 下 Gemini 的进程名通常是 `node` / `MainThread`，AI 列表按其 CLI 入口识别。

Gemini 的 `cli_help` 内置代理继承当前会话模型，避免网关拒绝它默认使用的 Flash。全局 `AGENTS.md` 仍由 `~/.gemini/GEMINI.md` 链接加载；另加 `GEMINI_CLI.md` 说明当前 CLI 的 shell 命令替换限制与可用写法。

Gemini 配置将 `~/.gemini/tmp` 和已存在的 `~/.codex/sessions` 加入持久化的 `context.includeDirectories`，让会话临时文件和 TMA 历史日志属于工作区，避免 YOLO 下反复将这些普通文件路径判为不可信参数。新会话自动加载；已运行会话可在空闲时用 `/directory add ~/.gemini/tmp, ~/.codex/sessions` 加载。该设置只解决这些目录中的普通文件路径；Gemini 对可执行脚本、外部参数和被修改的构建文件仍有独立确认。

跨项目任务还需把实际读取、写入的目录加入工作区，例如笔记目录和已有产物目录；启动时用 `--include-directories`，运行中用 `/directory add`。`trustedFolders` 的信任记录不等于工作区成员：即使目录已经受信任，从工具输出取得的工作区外路径仍可能触发确认。常用目录可写入 `context.includeDirectories`；一次性任务目录只加入当前会话。

pane 的状态存在 pane option 里（`@ai_agent_running` / `_background` / `_pending` / `_done` / `_unread` / `_woke`，含义见 `script/track_ai_agent_state.sh` 文件头），窗口是否由 Agent 创建存在 window option `@tma_created`。状态只由 `track_ai_agent_state.sh` 写；下面这些地方各自读它、各自画符号，加一种状态或改一个符号时要逐个改：

| 位置 | 文件 | 画法 |
| --- | --- | --- |
| 底部窗口列表 | `script/refresh_status_right.sh` 的 `decorate_window_status` | tmux 格式串里的 `state_symbol`；脚本只装饰一次，已运行的 tmux 要手动改 `window-status-format` / `window-status-current-format` 或重启 |
| 左下角计数 | `script/print_ai_status.sh` | running / `~`background / `!`unread 的数量 |
| `prefix + g` / `C-g` 选择器 | `ai/pane_list.awk`（`ai/lib.sh` 批量读取状态） | 符号、`[unread]` 这类标签、排序键；图例在 `ai/get_ai_pane.sh` 的 header；光标起点在 `_fzf_start_pos` 按标签找 |
| `prefix + C-a` 序列编辑器 | `auto-switch/sequence_edit.py` 的 `state_label`（状态写成单词）、`auto-switch/sequence.sh` 的 vim 高亮（`AutoSwitchState*`）和 `format_sequence.py` 的 `state_symbol`（加载 / 显示序列时消息里的符号） | |
| 终端标题 | `script/print_terminal_title.sh` | |
| 下一个 auto-switch 目标提示 | `auto-switch/print-waiting-hint.sh` | |
| auto-switch 跳过谁 | `auto-switch/switch-next.sh`、`auto-switch/refresh-next-pane.sh` | 只看 running / background / pending / done |

状态不是互斥的：unread 和 background 正交，后台还在跑、但这一轮在用户不在看时结束的 pane 两个都是，画成 ◓（带 unread 的 ◒），auto-switch 也会落到它上面；只有 background、没有 unread 的 pane 仍然被跳过。

**原生 Agent 事件校正层**是 `script/track_ai_agent_state.sh` 中标为 `Native Agent event correction` 的区段。原生 hook 报告的是前台回合事件：例如 Stop 传入 `idle`，此时仍可能有外部 watcher 等待唤醒。该区段结合外部工作状态校正事件，再交给后面的 `case` 应用 pane 状态和相关副作用；TUI tracker 补充的事件也经过这里。

当前校正规则是 `idle + 存活的 watch-target wakeup → background`。后续沿用正常的 background 转换：不在眼前且未静音就标未读，切入查看后清除未读。用 `python3 -m unittest configs/tmux/tests/test_background_state.py` 验证这条路径和状态切换顺序。

Codex 的 `UserPromptSubmit` 可能在自动压缩之后才触发。TUI tracker 看到实时的 `Compacting context (... esc to interrupt)` 工作条时就上报 `running`，让连续 auto-switch 在下一次检查时响应（默认每秒一次）。已完成的 `Context compacted` 历史行不触发；后续提交 hook 和回合中途的压缩不会重复发出 running 事件。`SessionStart` 仍不匹配 `compact`，避免压缩结束时清掉运行状态。

`prefix + u` 再按 `R`：将当前 tmux server 所有 session 的 TMA 标为已读，清除 unread / woke 标记，保留 running、background、pending、done 和最近访问记录。

改完跑 `python3 -m unittest configs/tmux/tests/test_state_symbols.py`：它检查画了某个符号的文件把同一族的符号都画了（比如有 unread 的 ◉ 就要有 woke 的 ☀），以及序列编辑器认识每种状态。加了新符号就把它补进测试里的 `FAMILIES` / `WORD_FILES`。
