#!/usr/bin/env bash

set -eu

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

tmux set-option -gq @ai_status_label "$label"
tmux refresh-client -S
