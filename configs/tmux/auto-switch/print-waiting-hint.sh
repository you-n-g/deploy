#!/usr/bin/env bash
set -euo pipefail

# Print a small status-right hint when the auto-switch sequence has a higher
# priority usable pane than the user's current pane.

ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
[ -n "$ranked" ] || exit 0

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
[ -n "$current_pane" ] || exit 0

pane_rows="$(tmux list-panes -a -F '#{pane_id}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_pending}' 2>/dev/null || true)"

lookup_pane_state() {
  local wanted="$1" pane running background pending

  while IFS='|' read -r pane running background pending; do
    [ "$pane" = "$wanted" ] || continue
    printf '%s|%s|%s\n' "$running" "$background" "$pending"
    return 0
  done <<< "$pane_rows"

  return 1
}

best_pane=""
for candidate in $ranked; do
  row="$(lookup_pane_state "$candidate" || true)"
  [ -n "$row" ] || continue
  IFS='|' read -r running background pending <<< "$row"
  if [ "$running" != "1" ] \
    && [ "$background" != "1" ] \
    && [ -z "$pending" ]; then
    best_pane="$candidate"
    break
  fi
done

[ -n "$best_pane" ] || exit 0
[ "$best_pane" = "$current_pane" ] && exit 0

printf ' 󰂚'
