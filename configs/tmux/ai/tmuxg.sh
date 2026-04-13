#!/bin/bash
# Select and switch to a tmux window running an AI agent.
# Usage: tmuxg

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

_ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)
CURRENT_TARGET=""

if [[ -n "$TMUX" ]]; then
    CURRENT_TARGET=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)
fi

_now=$(date +%s)
LIST=$(
    while IFS=' ' read -r wact sess_win wname pane_pid; do
        if _has_ai_proc "$pane_pid"; then
            _diff=$(( _now - wact ))
            if   (( _diff < 60 ));    then _rel="${_diff}s ago"
            elif (( _diff < 3600 ));  then _rel="$((_diff / 60))m ago"
            elif (( _diff < 86400 )); then _rel="$((_diff / 3600))h ago"
            else                           _rel="$((_diff / 86400))d ago"
            fi
            if [[ "$sess_win" == "$CURRENT_TARGET" ]]; then
                current_label=$'\033[1;30;43m current \033[0m '
            else
                current_label=""
            fi
            _date_str=$(date -d "@$wact" '+%m-%d %H:%M' 2>/dev/null || date -r "$wact" '+%m-%d %H:%M' 2>/dev/null)
            echo "$wact $sess_win ${current_label}${wname}  [${_date_str}, ${_rel}]"
        fi
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
    --ansi \
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
