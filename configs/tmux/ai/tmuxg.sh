#!/bin/bash
# Select and switch to a tmux window running an AI agent.
# Usage: tmuxg

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

_ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)

LIST=$(
    while IFS=' ' read -r wact sess_win wname pane_pid; do
        _has_ai_proc "$pane_pid" && echo "$wact $sess_win $wname"
    done < <(tmux list-panes -a \
        -F '#{window_activity} #{session_name}:#{window_index} #{window_name} #{pane_pid}' 2>/dev/null |
        sort -nr) |
    awk '!seen[$2]++' |
    cut -d' ' -f2-
)

if [[ -z "$LIST" ]]; then
    echo "No AI agent windows found."
    exit 0
fi

SELECTED=$(echo "$LIST" | fzf \
    --reverse \
    --header "Select an AI window (Enter to switch)" \
    --preview 'tmux capture-pane -ept {1}' \
    --preview-window 'up:70%,follow')

[[ -z "$SELECTED" ]] && exit 0

TARGET=$(echo "$SELECTED" | cut -d' ' -f1)

if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$TARGET"
else
    tmux attach-session -t "${TARGET%%:*}" \; select-window -t "$TARGET"
fi
