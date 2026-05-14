#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"
source "$SCRIPT_DIR/ai_label.sh"

fallback_target="${1:-}"

max_items="$(tmux show-options -gqv @status-ai-window-summary-count 2>/dev/null || true)"
case "$max_items" in
  ''|*[!0-9]*)
    max_items=6
    ;;
esac

if rows="$(_ai_window_rows -a)" && [ -n "$rows" ]; then
  count=0
  title=""

  while IFS=$'\t' read -r _last_visit sess_win window_name _window_id _pane_pid _activity_epoch _unread _running attribute; do
    [ -n "$sess_win" ] || continue

    count=$((count + 1))
    [ "$count" -le "$max_items" ] || break

    session_name="${sess_win%:*}"
    clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
    label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"

    if [ -n "$title" ]; then
      title="${title} | ${label}"
    else
      title="$label"
    fi
  done <<< "$rows"

  if [ -n "$title" ]; then
    printf '%s\n' "$title"
    exit 0
  fi
fi

if [ -n "$fallback_target" ]; then
  tmux display-message -p -t "$fallback_target" '#W' 2>/dev/null
else
  tmux display-message -p '#W' 2>/dev/null
fi
