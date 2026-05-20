#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"
source "$SCRIPT_DIR/ai_label.sh"

max_items="$(tmux show-options -gqv @status-ai-window-summary-count 2>/dev/null || true)"
case "$max_items" in
  ''|*[!0-9]*)
    max_items=6
    ;;
esac

if ! rows="$(_ai_pane_rows -a)"; then
  exit 0
fi
[ -n "$rows" ] || exit 0

current_target="$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
current_is_ai=0
if [ -n "$current_target" ]; then
  while IFS=$'\t' read -r _last_visit pane_target _window_name _pane_id _pane_pid _activity_epoch _unread _running _attribute; do
    if [ "$pane_target" = "$current_target" ]; then
      current_is_ai=1
      break
    fi
  done <<< "$rows"
fi

count=0
while IFS=$'\t' read -r _last_visit pane_target window_name pane_id _pane_pid _activity_epoch unread _running attribute; do
  [ -n "$pane_target" ] || continue
  [ "$pane_target" != "$current_target" ] || continue

  count=$((count + 1))
  [ "$count" -le "$max_items" ] || break

  session_name="${pane_target%:*}"
  range_id="aip_${pane_id#%}"

  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"

  if [ $(((count + current_is_ai) % 2)) -eq 0 ]; then
    bg='colour24'
    fg='colour255'
  else
    bg='colour52'
    fg='colour255'
  fi

  printf '#[range=user|%s]#[bg=%s,fg=%s]%s%s%s#[norange default]' \
    "$range_id" "$bg" "$fg" \
    "$(if [ "$unread" = "1" ]; then printf '#[bold,underscore]'; fi)" \
    "$label" \
    "$(if [ "$unread" = "1" ]; then printf '#[nobold,nounderscore]'; fi)"
done <<< "$rows"
