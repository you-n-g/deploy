#!/usr/bin/env bash
set -euo pipefail

# Print a small status-right hint when the auto-switch sequence has a higher
# priority usable pane than the user's current pane.

ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
[ -n "$ranked" ] || exit 0

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
[ -n "$current_pane" ] || exit 0

declare -A pane_exists pane_running pane_background pane_pending
while IFS=$'\037' read -r pane running background pending; do
  [ -n "$pane" ] || continue
  pane_exists["$pane"]=1
  pane_running["$pane"]="$running"
  pane_background["$pane"]="$background"
  pane_pending["$pane"]="$pending"
done < <(tmux list-panes -a -F $'#{pane_id}\037#{@ai_agent_running}\037#{@ai_agent_background}\037#{@ai_agent_pending}' 2>/dev/null)

best_pane=""
for candidate in $ranked; do
  [ -n "${pane_exists[$candidate]:-}" ] || continue
  if [ "${pane_running[$candidate]}" != "1" ] \
    && [ "${pane_background[$candidate]}" != "1" ] \
    && [ "${pane_pending[$candidate]}" != "1" ]; then
    best_pane="$candidate"
    break
  fi
done

[ -n "$best_pane" ] || exit 0
[ "$best_pane" = "$current_pane" ] && exit 0

printf ' 󰂚'
