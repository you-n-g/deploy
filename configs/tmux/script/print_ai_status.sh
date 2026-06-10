#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"
now="$(date +%s)"
stale_seconds="$(tmux show-options -gqv @ai_agent_stale_seconds 2>/dev/null || true)"
case "$stale_seconds" in
  ''|*[!0-9]*)
    stale_seconds=15
    ;;
esac

changed=0
ps_cache="$(ps -ax -o pid,ppid,comm 2>/dev/null || true)"

is_active_ai_tui() {
  local pane="$1" recent

  recent="$(tmux capture-pane -p -t "$pane" -S -30 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 8 || true)"
  printf '%s\n' "$recent" | tr '[:upper:]' '[:lower:]' | grep -Eq \
    'baking|working|esc[[:space:]]+to[[:space:]]+(interrupt|interupt)|press[[:space:]]+esc'
}

while IFS='|' read -r pane_id pane_pid window_activity window_active session_attached running background unread pending attribute; do
  if [ -n "${running}${background}${unread}${pending}${attribute}" ] && ! _has_ai_proc "$pane_pid" "$ps_cache"; then
    _clear_ai_pane_state "$pane_id"
    changed=1
    continue
  fi

  [ "$running" = "1" ] || continue
  [ "$window_activity" -gt 0 ] || continue

  if [ $((now - window_activity)) -ge "$stale_seconds" ]; then
    if is_active_ai_tui "$pane_id"; then
      continue
    fi
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    if [ "$window_active" = "1" ] && [ "$session_attached" != "0" ]; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    fi
    changed=1
  fi
done < <(tmux list-panes -a -F '#{pane_id}|#{pane_pid}|#{window_activity}|#{window_active}|#{session_attached}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_unread}|#{@ai_agent_pending}|#{@ai_agent_attribute}')

if [ "$changed" = "1" ]; then
  "$SCRIPT_DIR/refresh_terminal_title.sh"
fi

running=0
background=0
waiting=0
if rows="$(_ai_pane_rows -a)" && [ -n "$rows" ]; then
  rows="$(printf '%s\n' "$rows" | _tmuxg_filter_orchestrator_rows)"
  while IFS=$'\t' read -r _last_visit _pane_target _window_name _pane_id _pane_pid _activity_epoch pane_unread pane_running pane_background _pane_pending _pane_path _attribute; do
    [ -n "$_pane_target" ] || continue
    if [ "$pane_background" = "1" ]; then
      background=$((background + 1))
    elif [ "$pane_running" = "1" ]; then
      running=$((running + 1))
    elif [ "$pane_unread" = "1" ]; then
      waiting=$((waiting + 1))
    fi
  done <<< "$rows"
fi

parts=()
[ "$running" -gt 0 ] && parts+=("$running")
[ "$background" -gt 0 ] && parts+=("~${background}")
[ "$waiting" -gt 0 ] && parts+=("!${waiting}")
if [ "${#parts[@]}" -eq 0 ]; then
  label="0"
else
  label="${parts[*]}"
fi

printf '%s\n' "$label"
