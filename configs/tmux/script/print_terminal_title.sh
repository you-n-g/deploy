#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"
source "$SCRIPT_DIR/ai_label.sh"

ai_title_status_prefix() {
  local is_current="$1"
  local unread="$2"
  local running="$3"
  local background="$4"
  local pending="$5"

  if [ "$is_current" = "1" ]; then
    if [ "$pending" = "1" ]; then
      printf '⏸ '
    elif [ "$background" = "1" ]; then
      printf '➲ '
    elif [ "$running" = "1" ]; then
      printf '▶ '
    else
      printf '▷ '
    fi
    return
  fi

  if [ "$pending" = "1" ]; then
    printf '⏸ '
  elif [ "$background" = "1" ]; then
    printf '◒ '
  elif [ "$running" = "1" ]; then
    printf '● '
  elif [ "$unread" = "1" ]; then
    printf '◉ '
  else
    printf '○ '
  fi
}

append_title_item() {
  local item="$1"
  if [ -n "$title" ]; then
    title="${title} | ${item}"
  else
    title="$item"
  fi
}

format_title_item() {
  local pane_target="$1"
  local pane_id="$2"
  local window_name="$3"
  local unread="$4"
  local running="$5"
  local background="$6"
  local pending="$7"
  local attribute="$8"
  local session_name clean_attribute label is_current marker

  session_name="${pane_target%:*}"
  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"
  is_current=0
  [ "$pane_target" = "$current_target" ] && is_current=1
  marker=""
  [ -n "$marked_pane_id" ] && [ "$pane_id" = "$marked_pane_id" ] && marker="◆"
  printf '%s%s%s' "$(ai_title_status_prefix "$is_current" "$unread" "$running" "$background" "$pending")" "$label" "$marker"
}

current_target="$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
marked_pane_id="$(tmux display-message -p -t '{marked}' '#{pane_id}' 2>/dev/null || true)"

max_items="$(tmux show-options -gqv @status-ai-window-summary-count 2>/dev/null || true)"
case "$max_items" in
  ''|*[!0-9]*)
    max_items=6
    ;;
esac

if rows="$(_ai_pane_rows -a)" && [ -n "$rows" ]; then
  rows="$(printf '%s\n' "$rows" | _tmuxg_filter_orchestrator_rows)"
  [ -n "$rows" ] || rows=""
fi

if [ -n "${rows:-}" ]; then
  count=0
  title=""
  current_row=""

  if [ -n "$current_target" ]; then
    while IFS=$'\t' read -r _last_visit pane_target window_name pane_id _pane_pid _activity_epoch unread running background pending attribute; do
      if [ "$pane_target" = "$current_target" ]; then
        current_row="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "$attribute")"
        break
      fi
    done <<< "$rows"
  fi

  if [ -n "$current_row" ]; then
    IFS=$'\t' read -r pane_target pane_id window_name unread running background pending attribute <<< "$current_row"
    append_title_item "$(format_title_item "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "$attribute")"
    count=$((count + 1))
  fi

  while IFS=$'\t' read -r _last_visit pane_target window_name pane_id _pane_pid _activity_epoch unread running background pending attribute; do
    [ -n "$pane_target" ] || continue
    [ "$pane_target" != "$current_target" ] || continue

    count=$((count + 1))
    [ "$count" -le "$max_items" ] || break

    append_title_item "$(format_title_item "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "$attribute")"
  done <<< "$rows"

  if [ -n "$title" ]; then
    printf '%s\n' "$title"
    exit 0
  fi
fi

tmux display-message -p '#W' 2>/dev/null
