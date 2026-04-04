#!/bin/bash
# Find the most recently active AI window in a tmux session.
# Usage: ./get_ai_window.sh [-i] [session_name]
# -i: return window_id instead of window_name

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

[[ "$1" == "-i" ]] && { RETURN_ID=true; shift; } || RETURN_ID=false

SESSION=${1:-$(tmux display-message -p '#S' 2>/dev/null)}
[[ -z "$SESSION" ]] && exit 1

_ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)

while IFS=' ' read -r wname wact wid pane_pid; do
    if _has_ai_proc "$pane_pid"; then
        [[ "$RETURN_ID" == true ]] && echo "$wid" || echo "$wname"
        exit 0
    fi
done < <(tmux list-panes -s -t "$SESSION" \
    -F '#{window_name} #{window_activity} #{window_id} #{pane_pid}' 2>/dev/null |
    sort -k2,2nr)

exit 1
