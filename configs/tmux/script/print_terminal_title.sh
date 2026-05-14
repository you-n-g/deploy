#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"
source "$SCRIPT_DIR/ai_label.sh"

fallback_target="${1:-}"

ai_title_status_prefix() {
  local is_current="$1"
  local unread="$2"
  local running="$3"

  if [ "$is_current" = "1" ]; then
    if [ "$running" = "1" ]; then
      printf '◆ '
    else
      printf '◇ '
    fi
    return
  fi

  if [ "$running" = "1" ]; then
    printf '● '
  elif [ "$unread" = "1" ]; then
    printf '◉ '
  else
    printf '○ '
  fi
}

if [ -n "$fallback_target" ]; then
  current_target="$(tmux display-message -p -t "$fallback_target" '#{session_name}:#{window_index}')"
else
  current_target="$(tmux display-message -p '#{session_name}:#{window_index}')"
fi

max_items="$(tmux show-options -gqv @status-ai-window-summary-count 2>/dev/null || true)"
case "$max_items" in
  ''|*[!0-9]*)
    max_items=6
    ;;
esac

if rows="$(_ai_window_rows -a)" && [ -n "$rows" ]; then
  count=0
  title=""

  while IFS=$'\t' read -r _last_visit sess_win window_name _window_id _pane_pid _activity_epoch unread running attribute; do
    [ -n "$sess_win" ] || continue

    count=$((count + 1))
    [ "$count" -le "$max_items" ] || break

    session_name="${sess_win%:*}"
    clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
    label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"
    if [ "$sess_win" = "$current_target" ]; then
      item="$(ai_title_status_prefix 1 "$unread" "$running")${label}"
    else
      item="$(ai_title_status_prefix 0 "$unread" "$running")${label}"
    fi

    if [ -n "$title" ]; then
      title="${title} | ${item}"
    else
      title="$item"
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
