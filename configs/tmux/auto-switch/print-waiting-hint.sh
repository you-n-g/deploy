#!/usr/bin/env bash
set -euo pipefail

# Print a small status-right hint when the auto-switch sequence has a higher
# priority usable pane than the user's current pane.

source "$HOME/deploy/configs/tmux/ai/lib.sh"

ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
[ -n "$ranked" ] || exit 0

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
[ -n "$current_pane" ] || exit 0

ps_cache="$(ps -ax -o pid,ppid,comm 2>/dev/null || true)"

is_usable_pane() {
  local pane="$1" pane_pid running background pending

  pane_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null || true)"
  [ -n "$pane_pid" ] || return 1
  _has_ai_proc "$pane_pid" "$ps_cache" || return 1

  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane" @ai_agent_background 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane" @ai_agent_pending 2>/dev/null || true)"
  [ "$running" != "1" ] && [ "$background" != "1" ] && [ "$pending" != "1" ]
}

best_pane=""
for candidate in $ranked; do
  resolved="$(tmux display-message -p -t "$candidate" '#{pane_id}' 2>/dev/null || true)"
  [ -n "$resolved" ] || continue
  if is_usable_pane "$resolved"; then
    best_pane="$resolved"
    break
  fi
done

[ -n "$best_pane" ] || exit 0
[ "$best_pane" = "$current_pane" ] && exit 0

printf ' 󰂚'
