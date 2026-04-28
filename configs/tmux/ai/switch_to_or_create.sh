#!/bin/bash

# Switch to the most recent AI window in the CURRENT session.
# If none exists, create a new one based on TMUX_AI_TOOL.
# If user canceled selection (exit 2), do nothing.
#
# -q: quiet mode — always exit 0 (suppress non-zero exit codes).
#     Useful when called from tmux run-shell to avoid status-bar flash.
# --force-new: skip the switch lookup and always create a new AI window.
# --window-name NAME: switch to/create a specific AI window name in current session.

QUIET=false
FORCE_NEW=false
WINDOW_NAME=""
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

_create_new_ai_window() {
    local tool workdir cmd initial_window_name
    tool=$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null | cut -d= -f2)
    [ -z "$tool" ] && tool=claude
    initial_window_name="${WINDOW_NAME:-$tool}"
    workdir=$(tmux display-message -p '#{pane_current_path}')
    # Launch with interactive shell to ensure the tool runner is available
    if [[ -n "$WINDOW_NAME" ]]; then
        printf -v cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "$WINDOW_NAME" "${tool}r"
    else
        printf -v cmd 'zsh -ic %q' "${tool}r"
    fi
    tmux new-window -n "$initial_window_name" -c "$workdir" "$cmd"
}

if [[ "$FORCE_NEW" == true ]]; then
    _create_new_ai_window
    exit 0
fi

if [[ -n "$WINDOW_NAME" ]]; then
    SESSION=$(tmux display-message -p '#{session_name}')
    TARGET_WINDOW=$(
        tmux list-windows -t "$SESSION" -F '#{window_name}	#{window_id}' |
            awk -F '\t' -v name="$WINDOW_NAME" '$1 == name { print $2; exit }'
    )
    if [[ -n "$TARGET_WINDOW" ]]; then
        tmux select-window -t "$TARGET_WINDOW"
    else
        _create_new_ai_window
    fi
    exit 0
fi

TARGET_WINDOW=$("$SCRIPT_DIR/get_ai_window.sh" -i)
rc=$?

if [ $rc -eq 0 ] && [ -n "$TARGET_WINDOW" ]; then
    tmux select-window -t "$TARGET_WINDOW"
elif [ $rc -eq 1 ]; then
    # No AI window found — create one
    _create_new_ai_window
fi
# rc == 2: user canceled selection, do nothing
