---
name: respawn-ai
description: >
  Respawns tmux AI agent panes so they reload current authentication while
  preserving Codex sessions when possible. Use when Codex panes are logged into
  an old account, stale after auth changes, or the user asks to refresh all AI
  windows in tmux.
metadata:
  short-description: 刷新 AI pane 账号
---

# `respawn-ai` — 刷新 tmux AI pane

## 触发时机

- 用户说某个 tmux session/window 里的 Codex 账号是旧账号，需要更新。
- 用户要求把 `code`、当前 session、或所有 Codex / AI window 都 `respawn` 一遍。
- Codex TUI 已经启动，但需要重新读取当前 `~/.codex/auth.json`。

## 目标

把目标 Codex TUI pane 重启到当前账号，并尽量 resume 回原来的 Codex session。能精确恢复 session 时必须恢复；不能精确恢复时，不要用 `--last` 猜。

## 执行步骤

1. 固定 tmux 入口，后续命令都用同一个变量。不要在同一次操作里混用系统 `tmux` 和用户 wrapper；如果 `$HOME/bin/tmux` 存在，优先用它，因为它可能封装了正确 socket / 环境：

   ```bash
   TMUX_BIN="$(command -v tmux || true)"
   if [[ -x "$HOME/bin/tmux" ]]; then
     TMUX_BIN="$HOME/bin/tmux"
   fi
   [[ -n "$TMUX_BIN" ]] || { echo "tmux not found" >&2; exit 1; }
   ```

2. 先确认当前 pane，批量操作时跳过它，避免中断本次执行：

   ```bash
   "$TMUX_BIN" display-message -p '#S:#I.#{pane_index} #{pane_id}'
   ```

3. 列出候选 pane，保留 `window_id` 和 `window_panes`。默认只处理 `pane_current_command=node` 且子进程是 Codex CLI 的 pane；不要碰普通 shell、vim、ssh、训练任务或用户正在操作的非 Codex pane：

   ```bash
   "$TMUX_BIN" list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}\t#{window_id}\t#{pane_id}\t#{window_name}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_pid}\t#{window_panes}'
   ```

4. 对每个 Codex pane，用进程树找到 Rust 侧 Codex 进程，再用 `lsof` 读取它打开的 session jsonl。这个比从 pane 文本或目录猜 session 更可靠：

   ```bash
   pane_pid=<pane_pid>
   codex_node_pattern="${CODEX_NODE_PATTERN:-$HOME/apps/nodejs/bin/codex|.*/@openai/codex/bin/codex}"
   node_pid="$(pgrep -P "$pane_pid" -f "$codex_node_pattern" | head -n1)"
   rust_pid="$(pgrep -P "$node_pid" -f '/codex-linux-.*/bin/codex|/bin/codex' | head -n1)"
   session_file="$(lsof -p "$rust_pid" 2>/dev/null | awk '{print $9}' | grep -E '/\.codex/sessions/.+\.jsonl$' | head -n1)"
   session_id="$(basename "$session_file" .jsonl | sed -E 's/^rollout-[0-9TZ:-]+-//')"
   ```

5. 构造启动命令时用 bash array 和 `printf %q`，避免手写多层引号。需要刷新环境变量时，把它们显式放进 `env`，并在后续验证 `/proc/<rust_pid>/environ`：

   ```bash
   extra_env=()
   [[ -n "${RUST_LOG:-}" ]] && extra_env+=("RUST_LOG=$RUST_LOG")
   [[ -n "${CODEX_SQLITE_HOME:-}" ]] && extra_env+=("CODEX_SQLITE_HOME=$CODEX_SQLITE_HOME")
   inner="codexr resume $session_id; rc=\$?; echo; echo codexr exited with status \$rc; exec zsh -l"
   cmd_parts=(env "TMUX_AI_WINDOW_NAME=$window_name" "${extra_env[@]}" zsh -ic "$inner")
   printf -v command '%q ' "${cmd_parts[@]}"
   ```

6. 单 pane window 不要直接 `respawn-pane -k`。安全流程是：先在同一个 session 创建临时 window，确认新 Codex 进程已经起来并带着目标环境，再 kill 旧 window、move 临时 window 回原 index、恢复原 window 名。这样启动失败时旧窗口还在：

   ```bash
   tmp_wid="$("$TMUX_BIN" new-window -d -P -F '#{window_id}' -t "=<session>:" -n "__respawn_<index>_<name>" -c "$pane_current_path" "$command")"
   # 轮询 tmp_wid 的 pane_pid -> node_pid -> rust_pid，并检查 pane_current_command / 环境变量。
   "$TMUX_BIN" kill-window -t "$old_window_id"
   "$TMUX_BIN" move-window -s "$tmp_wid" -t "=<session>:<old_index>"
   "$TMUX_BIN" rename-window -t "=<session>:<old_index>" "$window_name"
   ```

7. 多 pane window 只替换目标 pane。先 `split-window -d` 创建新 pane，确认新 Codex 进程和环境正确，再 `swap-pane` 到旧 pane 位置并 kill 旧 pane。不要整窗替换多 pane window：

   ```bash
   new_pane="$("$TMUX_BIN" split-window -d -t "$old_pane_id" -c "$pane_current_path" -P -F '#{pane_id}' "$command")"
   # 轮询 new_pane 的 pane_pid -> node_pid -> rust_pid，并检查 pane_current_command / 环境变量。
   "$TMUX_BIN" swap-pane -s "$new_pane" -t "$old_pane_id"
   "$TMUX_BIN" kill-pane -t "$old_pane_id"
   ```

8. 如果某个 Codex pane 没有打开 session jsonl：

   - 先用 `/status` 或 `tmux capture-pane` 看它是否已经是新账号。
   - 如果能从 `/status` 得到明确 session id，可以用该 id resume。
   - 如果是空会话、0 token、或无法精确得到 session id，可以 fresh respawn；不要用 `codex resume --last`。

9. respawn 后核对进程和关键 pane：

   ```bash
   "$TMUX_BIN" display-message -p -t "=<session>:<window>.<pane>" '#{pane_pid} #{window_name} #{pane_current_command} #{pane_current_path}'
   "$TMUX_BIN" capture-pane -t "=<session>:<window>.<pane>" -p -S -80 | tail -n 40
   tr '\0' '\n' < /proc/<rust_pid>/environ | grep -E '^(RUST_LOG|CODEX_SQLITE_HOME|CODEX_HOME)='
   ```

## 约束

- 不要 respawn 当前执行任务的 pane，除非用户明确允许中断当前会话。
- 不要向已有业务运行 window、训练 window、ssh window 或非 Codex pane 发送输入。
- 不要用 `codex resume --last` 批量恢复；同目录多 agent 时很容易接错会话。
- 对 Claude pane 不套用 Codex session 恢复流程；除非能确认对应 CLI 的安全 resume 方式，否则只列出并报告。
- 对单 pane window，默认使用“新 window 验证后替换旧 window”的流程；只有用户明确接受风险，或目标 pane 不是唯一 pane 时，才考虑直接 `respawn-pane -k`。
- 如果替换过程中临时 window 没有启动成功，不要杀旧 window；保留临时 window 的错误输出或报告其 `window_id`。
- 如果 session 名可能和另一个 session 前缀冲突，例如 `code` 与 `code-learn`，必须用 `=<session>` 精确匹配。

## 验证

- 目标 pane 的 `pane_current_command` 应回到 `node`。
- `/status` 或底部状态行应显示当前账号或新的 quota 状态。
- 对被保留的会话，pane 内容应仍是原 session 的上下文，而不是误接到另一个 agent。
- 如果本次 respawn 是为了加载新环境，必须从 Rust 侧 Codex 进程的 `/proc/<pid>/environ` 验证目标变量已经生效；例如日志/SQLite 调整要检查 `RUST_LOG` 和 `CODEX_SQLITE_HOME`。
