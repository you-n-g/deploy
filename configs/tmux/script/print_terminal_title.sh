#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

ai_title_status_prefix() {
  local is_current="$1"
  local unread="$2"
  local running="$3"
  local background="$4"
  local pending="$5"
  local done="$6"
  local woke="${7:-0}"

  if [ "$is_current" = "1" ]; then
    if [ -n "$pending" ] && [ "$pending" != "0" ]; then
      printf '⏸ '
    elif [ "$background" = "1" ]; then
      printf '➲ '
    elif [ "$running" = "1" ]; then
      printf '▶ '
    elif [ "$done" = "1" ]; then
      printf '✓ '
    else
      printf '▷ '
    fi
    return
  fi

  if [ -n "$pending" ] && [ "$pending" != "0" ]; then
    printf '⏸ '
  elif [ "$background" = "1" ] && [ "$unread" = "1" ]; then
    printf '◓ '
  elif [ "$background" = "1" ]; then
    printf '◒ '
  elif [ "$running" = "1" ]; then
    printf '● '
  elif [ "$done" = "1" ]; then
    printf '✓ '
  elif [ "$unread" = "1" ] && [ "$woke" = "1" ]; then
    printf '☀ '
  elif [ "$unread" = "1" ]; then
    printf '◉ '
  else
    printf '○ '
  fi
}

# The title's panes, current first: collected, then labelled in one python start
# (compact_ai_label.py). A python start per label made this -- run on every
# agent state change -- the slow part of Claude's state hook.
items=()

add_title_item() {
  # \x1f, not a tab: read collapses consecutive tabs, and empty fields are common.
  items+=("$(printf '%s\x1f' "$@")")
}

format_title_item() {
  local pane_target="$1"
  local pane_id="$2"
  local window_name="$3"
  local unread="$4"
  local running="$5"
  local background="$6"
  local pending="$7"
  local label="$8"
  local is_current marker

  is_current=0
  [ "$pane_target" = "$current_target" ] && is_current=1
  marker=""
  [ -n "$marked_pane_id" ] && [ "$pane_id" = "$marked_pane_id" ] && marker="◆"
  done=0
  [[ "$done_pane_ids" == *" $pane_id "* ]] && done=1
  woke=0
  [[ "$woke_pane_ids" == *" $pane_id "* ]] && woke=1
  printf '%s%s%s' "$(ai_title_status_prefix "$is_current" "$unread" "$running" "$background" "$pending" "$done" "$woke")" "$label" "$marker"
}

current_target="$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
done_pane_ids=" $(_ai_done_pane_ids | tr '\n' ' ') "
woke_pane_ids=" $(_ai_woke_pane_ids | tr '\n' ' ') "
marked_pane_id="$(tmux display-message -p -t '{marked}' '#{pane_id}' 2>/dev/null || true)"

max_items="$(tmux show-options -gqv @status-ai-window-summary-count 2>/dev/null || true)"
case "$max_items" in
  ''|*[!0-9]*)
    max_items=6
    ;;
esac

if rows="$(_ai_pane_rows -a)" && [ -n "$rows" ]; then
  rows="$(printf '%s\n' "$rows" |
    _tmuxg_filter_orchestrator_rows |
    _tmuxg_filter_blacklisted_session_rows)"
  [ -n "$rows" ] || rows=""
fi

if [ -n "${rows:-}" ]; then
  count=0
  title=""
  current_row=""

  if [ -n "$current_target" ]; then
    while IFS=$'\t' read -r _last_visit pane_target window_name pane_id _pane_pid _activity_epoch unread running background pending _pane_path attribute; do
      if [ "$pane_target" = "$current_target" ]; then
        current_row="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "$attribute")"
        break
      fi
    done <<< "$rows"
  fi

  if [ -n "$current_row" ]; then
    IFS=$'\t' read -r pane_target pane_id window_name unread running background pending attribute <<< "$current_row"
    add_title_item "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "$attribute"
    count=$((count + 1))
  fi

  while IFS=$'\t' read -r _last_visit pane_target window_name pane_id _pane_pid _activity_epoch unread running background pending _pane_path attribute; do
    [ -n "$pane_target" ] || continue
    [ "$pane_target" != "$current_target" ] || continue

    count=$((count + 1))
    [ "$count" -le "$max_items" ] || break

    add_title_item "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "$attribute"
  done <<< "$rows"

  if [ "${#items[@]}" -gt 0 ]; then
    # session (from session:window.pane), window, attribute -> one label per line
    mapfile -t labels < <(for item in "${items[@]}"; do
      IFS=$'\x1f' read -r pane_target _ window_name _ _ _ _ attribute _ <<< "$item"
      printf '%s\t%s\t%s\n' "${pane_target%:*}" "$window_name" "$attribute"
    done | python3 "$SCRIPT_DIR/compact_ai_label.py")
    for i in "${!items[@]}"; do
      IFS=$'\x1f' read -r pane_target pane_id window_name unread running background pending _ <<< "${items[$i]}"
      item="$(format_title_item "$pane_target" "$pane_id" "$window_name" "$unread" "$running" "$background" "$pending" "${labels[$i]}")"
      title="${title:+$title | }$item"
    done
  fi

  if [ -n "$title" ]; then
    printf '%s\n' "$title"
    exit 0
  fi
fi

tmux display-message -p '#W' 2>/dev/null
