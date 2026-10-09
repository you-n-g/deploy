#!/usr/bin/env bash
# Turn a tiled Claude pane into a floating pane of the same window.
#
# tmux 3.7b cannot make an existing pane floating (join-pane / move-pane -f
# means full width or height, not floating), so the pane is recreated: a new
# floating pane resumes the same Claude session (`clauder --resume <id>`) once
# the old process has exited, and the old pane is killed. The process does not
# survive, which is why this refuses a pane that is running or has background
# work, and only Claude panes qualify: nothing else can be resumed.
#
# The new pane takes over the old one's identity where it is referenced by
# pane id: its @ai_agent_* options and @last_visit, its place in the active
# and saved auto-switch sequences, and other panes' "等 %id" / "等完成 %id"
# pending reasons. It also becomes the window's @float_ai pane when there is
# none (nvim's \c<what>f target).
#
# usage: split_to_float.sh PANE
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fail() { tmux display-message "split_to_float: $1"; exit 1; }

old="$(tmux display-message -p -t "${1:?usage: split_to_float.sh PANE}" '#{pane_id}')"
# In a zoomed window tmux reports floating panes with pane_floating_flag 0, so
# unzoom before telling floats from splits (new_float_pane.sh would anyway).
[[ "$(tmux display-message -p -t "$old" '#{window_zoomed_flag}')" != 1 ]] || tmux resize-pane -Z -t "$old"
read -r window floating pane_pid < <(tmux display-message -p -t "$old" '#{window_id} #{pane_floating_flag} #{pane_pid}')
[[ "$floating" != 1 ]] || fail "已经是浮窗"
tiled="$(tmux list-panes -t "$window" -f '#{!=:#{pane_floating_flag},1}' -F x | wc -l)"
(( tiled > 1 )) || fail "这是窗口里唯一的分屏，变成浮窗后底下就没有 pane 了"
[[ "$(tmux show-option -pqv -t "$old" @ai_agent_running)" != 1 \
  && "$(tmux show-option -pqv -t "$old" @ai_agent_background)" != 1 ]] \
  || fail "Claude 正在运行或有后台任务，等它停下再转"

# The claude process under the pane, and the session it has open.
claude_pid="$(ps -u "$USER" -o pid=,ppid=,comm= | awk -v root="$pane_pid" '
  { parent[$1] = $2; name[$1] = $3 }
  END {
    for (pid in name) {
      if (name[pid] != "claude") continue
      for (p = pid; p in parent; p = parent[p]) if (p == root) { print pid; exit }
    }
  }')"
[[ -n "$claude_pid" ]] || fail "不是 Claude pane，只有 Claude 会话能接回"
session_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions/$claude_pid.json"
[[ -f "$session_file" ]] || fail "找不到 $session_file"
session_id="$(jq -r '.sessionId' "$session_file")"
cwd="$(jq -r '.cwd' "$session_file")"

# The top-right quarter of the window, as ensure_float_ai_pane.sh places the
# floating AI pane. The command waits for the old process to exit so two
# processes never hold one session.
read -r win_w win_h < <(tmux display-message -p -t "$old" '#{window_width} #{window_height}')
fw=$(( win_w / 2 )); fh=$(( win_h / 2 ))
printf -v cmd 'while kill -0 %s 2>/dev/null; do sleep 0.2; done; TMUX_AI_DISABLE_RENAME=1 exec zsh -ic %q' \
  "$claude_pid" "clauder --resume $session_id"
new="$("$script_dir/new_float_pane.sh" "$old" -x "$fw" -y "$fh" \
  -X "$(( win_w - fw - 1 ))" -Y 1 -c "$cwd" "$cmd")"

while read -r name _; do
  tmux set-option -pq -t "$new" "$name" "$(tmux show-option -pqv -t "$old" "$name")"
done < <(tmux show-options -p -t "$old" | grep -E '^@(ai_agent_[a-z_]+|last_visit) ')
if ! tmux list-panes -t "$window" -F '#{@float_ai}' | grep -qx 1; then
  tmux set-option -pq -t "$new" @float_ai 1
fi

swap_id() { sed -E "s/(^|[[:space:]])$old([[:space:]]|\$)/\\1$new\\2/g"; }
for option in @auto_switch_ranked_panes @auto_switch_saved_ranked_panes; do
  value="$(tmux show-option -gqv "$option")"
  [[ -z "$value" ]] || tmux set-option -gq "$option" "$(printf '%s' "$value" | swap_id)"
done
while IFS=$'\t' read -r pane reason; do
  case "$reason" in
    "等 $old"|"等 $old "*|"等完成 $old"|"等完成 $old "*)
      tmux set-option -pq -t "$pane" @ai_agent_pending "$(printf '%s' "$reason" | swap_id)" ;;
  esac
done < <(tmux list-panes -a -F $'#{pane_id}\t#{@ai_agent_pending}')

tmux kill-pane -t "$old"
