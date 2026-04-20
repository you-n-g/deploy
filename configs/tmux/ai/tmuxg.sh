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
    while IFS=' ' read -r wact sess_win wname pane_pid wact_raw; do
        if _has_ai_proc "$pane_pid"; then
            if [[ "$sess_win" == "$CURRENT_TARGET" ]]; then
                _sort_key=0
                _status=$'\033[36m◆\033[0m '
            elif (( _now - wact_raw > 1 )); then
                _sort_key=1
                _status=$'\033[32m●\033[0m '
            else
                _sort_key=05
                _status=$'\033[33m○\033[0m '
            fi

            _diff_visit=$(( _now - wact ))
            if   (( _diff_visit < 60 ));    then _rel_visit="${_diff_visit}s"
            elif (( _diff_visit < 3600 ));  then _rel_visit="$((_diff_visit / 60))m"
            elif (( _diff_visit < 86400 )); then _rel_visit="$((_diff_visit / 3600))h"
            else                                 _rel_visit="$((_diff_visit / 86400))d"
            fi

            _diff_act=$(( _now - wact_raw ))
            if   (( _diff_act < 60 ));    then _rel_act="${_diff_act}s"
            elif (( _diff_act < 3600 ));  then _rel_act="$((_diff_act / 60))m"
            elif (( _diff_act < 86400 )); then _rel_act="$((_diff_act / 3600))h"
            else                               _rel_act="$((_diff_act / 86400))d"
            fi
            if (( wact == wact_raw )); then
                _time_info="[act ${_rel_act}]"
            else
                _time_info="[visit ${_rel_visit} | act ${_rel_act}]"
            fi
            echo "$_sort_key $wact $sess_win ${_status}${wname}  "$'\033[2m'"${_time_info}"$'\033[0m'
        fi
    done < <(tmux list-panes -a \
        -F '#{?@last_visit,#{@last_visit},#{window_activity}} #{session_name}:#{window_index} #{window_name} #{pane_pid} #{window_activity}' 2>/dev/null) |
    sort -k1,1 -k2,2nr |
    awk '!seen[$3]++' |
    cut -d' ' -f3-
)

if [[ -z "$LIST" ]]; then
    echo "No AI agent windows found."
    exit 0
fi

SKIP_COUNT=$(printf '%s\n' "$LIST" | grep -cvF $'\033[32m●' || true)

if (( SKIP_COUNT > 0 )); then
    _downs=$(printf '+down%.0s' $(seq 1 "$SKIP_COUNT"))
    _start_bind="--bind=load:${_downs#+}"
else
    _start_bind=""
fi

SELECTED=$(echo "$LIST" | fzf \
    --ansi \
    --reverse \
    $_start_bind \
    --header $'\033[36m◆\033[0m current  \033[33m○\033[0m busy  \033[32m●\033[0m ready  |  Enter to switch' \
    --preview 'tmux capture-pane -ept {1}' \
    --preview-window 'up:70%,follow')

[[ -z "$SELECTED" ]] && exit 0

TARGET=$(echo "$SELECTED" | cut -d' ' -f1)

if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$TARGET"
else
    tmux attach-session -t "${TARGET%%:*}" \; select-window -t "$TARGET"
fi
