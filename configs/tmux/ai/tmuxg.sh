#!/bin/bash
# Select and switch to a tmux window running an AI agent.
# Usage: tmuxg [-q] [-A] [--create-if-missing] [--force-new] [--window-name NAME]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

QUIET=false
ALL_SESSIONS=false
CREATE_IF_MISSING=false
FORCE_NEW=false
WINDOW_NAME=""
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        -A) ALL_SESSIONS=true; shift ;;
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
    local tool workdir cmd initial_window_name
    tool=$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null | cut -d= -f2)
    [ -z "$tool" ] && tool=claude
    initial_window_name="${WINDOW_NAME:-$tool}"
    workdir=$(tmux display-message -p '#{pane_current_path}')

    if [[ -n "$WINDOW_NAME" ]]; then
        printf -v cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "$WINDOW_NAME" "${tool}r"
    else
        printf -v cmd 'zsh -ic %q' "${tool}r"
    fi
    tmux new-window -n "$initial_window_name" -c "$workdir" "$cmd"
}

_switch_to_window() {
    local target="${1:?usage: _switch_to_window TARGET}"
    local session

    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$target"
    elif [[ -t 0 ]]; then
        session=$(tmux display-message -t "$target" -p '#{session_name}')
        tmux attach-session -t "$session" \; select-window -t "$target"
    else
        tmux switch-client -t "$target"
    fi
}

if [[ "$FORCE_NEW" == true ]]; then
    _create_new_ai_window
    exit 0
fi

if [[ -n "$WINDOW_NAME" ]]; then
    SESSION=$(tmux display-message -p '#{session_name}')
    TARGET=$(
        tmux list-windows -t "$SESSION" -F '#{window_name}	#{window_id}' |
            awk -F '\t' -v name="$WINDOW_NAME" '$1 == name { print $2; exit }'
    )

    if [[ -n "$TARGET" ]]; then
        _switch_to_window "$TARGET"
    else
        _create_new_ai_window
    fi
    exit 0
fi

GET_AI_WINDOW_ARGS=(-i)
if [[ "$ALL_SESSIONS" == true ]]; then
    GET_AI_WINDOW_ARGS+=(-A)
fi

TARGET=$("$SCRIPT_DIR/get_ai_window.sh" "${GET_AI_WINDOW_ARGS[@]}")
rc=$?

if [[ $rc -eq 1 ]]; then
    if [[ "$CREATE_IF_MISSING" == true ]]; then
        _create_new_ai_window
        exit 0
    fi

    echo "No AI agent windows found."
    exit 0
fi

if [[ $rc -eq 2 ]]; then
    exit 0
fi

[[ $rc -eq 0 && -n "$TARGET" ]] || exit "$rc"

_switch_to_window "$TARGET"
