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

1. 先确认当前 pane，批量操作时跳过它，避免中断本次执行：

   ```bash
   tmux display-message -p '#S:#I.#{pane_index} #{pane_id}'
   ```

2. 列出候选 pane。默认只处理 `pane_current_command=node` 且子进程是 Codex CLI 的 pane；不要碰普通 shell、vim、ssh、训练任务或用户正在操作的非 Codex pane：

   ```bash
   tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}\t#{pane_id}\t#{window_name}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_pid}'
   ```

3. 对每个 Codex pane，用进程树找到 Rust 侧 Codex 进程，再用 `lsof` 读取它打开的 session jsonl。这个比从 pane 文本或目录猜 session 更可靠：

   ```bash
   pane_pid=<pane_pid>
   node_pid="$(pgrep -P "$pane_pid" -f '/home/xiaoyang/apps/nodejs/bin/codex' | head -n1)"
   rust_pid="$(pgrep -P "$node_pid" -f '/codex/codex' | head -n1)"
   lsof -p "$rust_pid" 2>/dev/null | rg '\.codex/sessions/.+\.jsonl'
   ```

4. 从 session 文件名中提取 `019...` session id，然后用精确 tmux target respawn：

   ```bash
   tmux respawn-pane -k -t "=<session>:<window>.<pane>" -c "<pane_current_path>" \
     "env TMUX_AI_WINDOW_NAME=<window_name> zsh -ic 'codexr resume <session_id>'"
   ```

   如果 session 名可能和另一个 session 前缀冲突，例如 `code` 与 `code-learn`，必须用 `=<session>` 精确匹配。

5. 如果某个 Codex pane 没有打开 session jsonl：

   - 先用 `/status` 或 `tmux capture-pane` 看它是否已经是新账号。
   - 如果能从 `/status` 得到明确 session id，可以用该 id resume。
   - 如果是空会话、0 token、或无法精确得到 session id，可以 fresh respawn；不要用 `codex resume --last`。

6. respawn 后核对进程和关键 pane：

   ```bash
   tmux display-message -p -t "=<session>:<window>.<pane>" '#{pane_pid} #{window_name} #{pane_current_command} #{pane_current_path}'
   tmux capture-pane -t "=<session>:<window>.<pane>" -p -S -40
   ```

## 约束

- 不要 respawn 当前执行任务的 pane，除非用户明确允许中断当前会话。
- 不要向已有业务运行 window、训练 window、ssh window 或非 Codex pane 发送输入。
- 不要用 `codex resume --last` 批量恢复；同目录多 agent 时很容易接错会话。
- 对 Claude pane 不套用 Codex session 恢复流程；除非能确认对应 CLI 的安全 resume 方式，否则只列出并报告。
- 如果 `respawn-pane` 因 wrapper 或 tmux target 歧义导致 window 消失，先用精确 target 复查；必要时用 Codex CLI 直接 fresh 创建 window。

## 验证

- 目标 pane 的 `pane_current_command` 应回到 `node`。
- `/status` 或底部状态行应显示当前账号或新的 quota 状态。
- 对被保留的会话，pane 内容应仍是原 session 的上下文，而不是误接到另一个 agent。
