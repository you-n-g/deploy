#!/usr/bin/env bash

set -eu

refresh_client=0
if [ "${1:-}" = "--refresh" ]; then
  refresh_client=1
fi

now="$(date +%s)"
stale_seconds="$(tmux show-options -gqv @ai_agent_stale_seconds 2>/dev/null || true)"
case "$stale_seconds" in
  ''|*[!0-9]*)
    stale_seconds=15
    ;;
esac

tmux list-windows -a -F '#{window_id}	#{window_activity}	#{window_active}	#{session_attached}	#{@ai_agent_running}' |
  while IFS=$'\t' read -r window_id window_activity window_active session_attached running; do
    [ "$running" = "1" ] || continue
    [ "$window_activity" -gt 0 ] || continue

    if [ $((now - window_activity)) -ge "$stale_seconds" ]; then
      tmux set-window-option -q -t "$window_id" @ai_agent_running 0
      if [ "$window_active" = "1" ] && [ "$session_attached" != "0" ]; then
        tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
      else
        tmux set-window-option -q -t "$window_id" @ai_agent_unread 1
      fi
    fi
  done

read -r running waiting < <(
  tmux list-windows -a -F '#{@ai_agent_running}	#{@ai_agent_unread}' |
    awk -F '\t' '
      $1 != "" {
        if ($1 == 1) running++
        else if ($2 == 1) waiting++
      }
      END { print running+0 " " waiting+0 }
    '
)

if [ "$waiting" -gt 0 ] && [ "$running" -gt 0 ]; then
  label="${running} !${waiting}"
elif [ "$waiting" -gt 0 ]; then
  label="!${waiting}"
else
  label="$running"
fi

printf '%s\n' "$label"
if [ "$refresh_client" = "1" ]; then
  tmux refresh-client -S
fi
