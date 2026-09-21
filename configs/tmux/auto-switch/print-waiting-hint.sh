#!/usr/bin/env bash
set -euo pipefail

# Print a small status-right hint when the auto-switch sequence has a higher
# priority usable pane than the user's current pane.

ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
[ -n "$ranked" ] || exit 0

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
[ -n "$current_pane" ] || exit 0

pane_rows="$(tmux list-panes -a -F '#{pane_id}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_unread}|#{@ai_agent_pending}' 2>/dev/null || true)"

lookup_pane_state() {
  local wanted="$1" pane running background unread pending

  while IFS='|' read -r pane running background unread pending; do
    [ "$pane" = "$wanted" ] || continue
    printf '%s|%s|%s|%s\n' "$running" "$background" "$unread" "$pending"
    return 0
  done <<< "$pane_rows"

  return 1
}

state_symbol() {
  local running="$1" background="$2" unread="$3" pending="$4"

  if [ -n "$pending" ]; then
    printf '⏸'
  elif [ "$background" = "1" ]; then
    printf '◒'
  elif [ "$running" = "1" ]; then
    printf '●'
  elif [ "$unread" = "1" ]; then
    printf '◉'
  else
    printf '○'
  fi
}

best_pane=""
best_symbol=""
for candidate in $ranked; do
  row="$(lookup_pane_state "$candidate" || true)"
  [ -n "$row" ] || continue
  IFS='|' read -r running background unread pending <<< "$row"
  if [ "$running" != "1" ] \
    && [ "$background" != "1" ] \
    && [ -z "$pending" ]; then
    best_pane="$candidate"
    best_symbol="$(state_symbol "$running" "$background" "$unread" "$pending")"
    break
  fi
done

[ -n "$best_pane" ] || exit 0
[ "$best_pane" = "$current_pane" ] && exit 0

# Leading space only: the status format puts nothing between the agent counts
# and this slot, so an absent hint leaves no gap before the mode symbol.
printf ' %s' "$best_symbol"
