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
  while IFS=$'\t' read -r _last_visit pane_target _window_name _pane_id _pane_pid _activity_epoch _unread _running _background _attribute; do
    if [ "$pane_target" = "$current_target" ]; then
      current_is_ai=1
      break
    fi
  done <<< "$rows"
fi

count=0
while IFS=$'\t' read -r _last_visit pane_target window_name pane_id _pane_pid _activity_epoch unread running background attribute; do
  [ -n "$pane_target" ] || continue
  [ "$pane_target" != "$current_target" ] || continue

  count=$((count + 1))
  [ "$count" -le "$max_items" ] || break

  session_name="${pane_target%:*}"
  range_id="aip_${pane_id#%}"

  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"

  if [ $(((count + current_is_ai) % 2)) -eq 0 ]; then
    normal_bg='colour24'
    running_bg='colour153'
  else
    normal_bg='colour52'
    running_bg='colour217'
  fi

  if [ "$background" = "1" ]; then
    bg="$running_bg"
    fg='colour244'
  elif [ "$running" = "1" ]; then
    bg="$running_bg"
    fg='colour235'
  else
    bg="$normal_bg"
    fg='colour255'
  fi
  pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
  if [ "$pending" = "1" ]; then
    if [ "$running" = "1" ]; then
      fg='colour238'
    else
      fg='colour250'
    fi
  fi
  if [ "$background" = "1" ]; then
    label="◒${label}"
  fi

  printf '#[range=user|%s]#[bg=%s,fg=%s]%s%s%s#[norange default]' \
    "$range_id" "$bg" "$fg" \
    "$(if [ "$unread" = "1" ]; then printf '#[bold,underscore]'; fi)" \
    "$label" \
    "$(if [ "$unread" = "1" ]; then printf '#[nobold,nounderscore]'; fi)"
done <<< "$rows"
