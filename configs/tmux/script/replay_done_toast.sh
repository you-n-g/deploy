#!/usr/bin/env bash
# Show the most recent task-done toast again over HOST_PANE, for a completion
# noticed too late: the pane show_done_toast.sh last recorded, previewed live.
# prefix + t r.
#
# usage: replay_done_toast.sh HOST_PANE
set -euo pipefail

host="${1:?usage: replay_done_toast.sh HOST_PANE}"
pane="$(tmux show-option -gqv @last_done_toast_pane)"
[[ -n "$pane" ]] || { tmux display-message "还没有显示过完成提示"; exit 0; }
tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1 \
  || { tmux display-message "上次完成提示的 pane 已经关闭：$pane"; exit 0; }
exec "$(dirname -- "${BASH_SOURCE[0]}")/show_done_toast.sh" "$pane" "$host"
