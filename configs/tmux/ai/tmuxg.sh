#!/bin/bash
# Select and switch to a tmux pane running an AI agent.
# Usage: tmuxg [-q] [-A] [--auto-switch-list] [--create-if-missing] [--force-new] [--window-name NAME]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

QUIET=false
ALL_SESSIONS=false
AUTO_SWITCH_LIST=false
CREATE_IF_MISSING=false
FORCE_NEW=false
WINDOW_NAME=""
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        -A) ALL_SESSIONS=true; shift ;;
        --auto-switch-list) AUTO_SWITCH_LIST=true; ALL_SESSIONS=true; shift ;;
        --create-if-missing) CREATE_IF_MISSING=true; shift ;;
        --force-new) FORCE_NEW=true; shift ;;
        --window-name)
            if [[ -z "$2" ]]; then
                echo "--window-name requires a name" >&2
                exit 2
            fi
            WINDOW_NAME="$2"
            shift 2
            ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

_create_new_ai_window() {
    local tool workdir cmd window_name
    tool=$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null | cut -d= -f2)
    [ -z "$tool" ] && tool=codex
    workdir=$(tmux display-message -p '#{pane_current_path}')
    window_name="${WINDOW_NAME:-${workdir##*/}}"

    printf -v cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "$window_name" "${tool}r"
    tmux new-window -n "$window_name" -c "$workdir" "$cmd"
}

_switch_to_window() {
    local target="${1:?usage: _switch_to_window TARGET}"
    local session window_id pane_id

    session=$(tmux display-message -t "$target" -p '#{session_name}') || exit 1
    window_id=$(tmux display-message -t "$target" -p '#{window_id}') || exit 1
    pane_id=$(tmux display-message -t "$target" -p '#{pane_id}') || exit 1

    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$session"
        tmux select-window -t "$window_id"
        tmux select-pane -t "$pane_id"
    elif [[ -t 0 ]]; then
        tmux attach-session -t "$session" \; select-window -t "$window_id" \; select-pane -t "$pane_id"
    else
        tmux switch-client -t "$session"
        tmux select-window -t "$window_id"
        tmux select-pane -t "$pane_id"
    fi
}

if [[ "$FORCE_NEW" == true ]]; then
    _create_new_ai_window
    exit 0
fi

if [[ -n "$WINDOW_NAME" ]]; then
    SESSION=$(tmux display-message -p '#{session_name}')
    TARGET=""
    while IFS=$'\t' read -r window_name window_id; do
        if [[ "$window_name" == "$WINDOW_NAME" ]]; then
            TARGET="$window_id"
            break
        fi
    done < <(tmux list-windows -t "$SESSION" -F '#{window_name}	#{window_id}')

    if [[ -n "$TARGET" ]]; then
        _switch_to_window "$TARGET"
    else
        _create_new_ai_window
    fi
    exit 0
fi

GET_AI_PANE_ARGS=(-i)
if [[ "$AUTO_SWITCH_LIST" == true ]]; then
    GET_AI_PANE_ARGS+=(--auto-switch-list)
elif [[ "$ALL_SESSIONS" == true ]]; then
    GET_AI_PANE_ARGS+=(-A)
fi

TARGET=$("$SCRIPT_DIR/get_ai_pane.sh" "${GET_AI_PANE_ARGS[@]}")
rc=$?

if [[ $rc -eq 1 ]]; then
    if [[ "$CREATE_IF_MISSING" == true ]]; then
        _create_new_ai_window
        exit 0
    fi

    echo "No AI agent panes found."
    exit 0
fi

if [[ $rc -eq 2 ]]; then
    exit 0
fi

[[ $rc -eq 0 && -n "$TARGET" ]] || exit "$rc"

_switch_to_window "$TARGET"
