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

while IFS='|' read -r pane_id pane_pid window_activity window_active session_attached running unread attribute; do
  if [ -n "${running}${unread}${attribute}" ] && ! _has_ai_proc "$pane_pid" "$ps_cache"; then
    _clear_ai_pane_state "$pane_id"
    changed=1
    continue
  fi

  [ "$running" = "1" ] || continue
  [ "$window_activity" -gt 0 ] || continue

  if [ $((now - window_activity)) -ge "$stale_seconds" ]; then
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    if [ "$window_active" = "1" ] && [ "$session_attached" != "0" ]; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    fi
    changed=1
  fi
done < <(tmux list-panes -a -F '#{pane_id}|#{pane_pid}|#{window_activity}|#{window_active}|#{session_attached}|#{@ai_agent_running}|#{@ai_agent_unread}|#{@ai_agent_attribute}')

if [ "$changed" = "1" ]; then
  "$SCRIPT_DIR/refresh_terminal_title.sh"
fi

running=0
waiting=0
while IFS='|' read -r pane_pid pane_running pane_unread; do
  _has_ai_proc "$pane_pid" "$ps_cache" || continue
  if [ "$pane_running" = "1" ]; then
    running=$((running + 1))
  elif [ "$pane_unread" = "1" ]; then
    waiting=$((waiting + 1))
  fi
done < <(tmux list-panes -a -F '#{pane_pid}|#{@ai_agent_running}|#{@ai_agent_unread}')

if [ "$waiting" -gt 0 ] && [ "$running" -gt 0 ]; then
  label="${running} !${waiting}"
elif [ "$waiting" -gt 0 ]; then
  label="!${waiting}"
else
  label="$running"
fi

printf '%s\n' "$label"
