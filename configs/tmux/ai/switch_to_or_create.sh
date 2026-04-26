#!/bin/bash

# Switch to the most recent 'gemini' or 'codex' window in the CURRENT session.
# If neither exists, create a new one based on PREFERRED_AI_TOOL.
# If user canceled selection (exit 2), do nothing.
#
# -q: quiet mode — always exit 0 (suppress non-zero exit codes).
#     Useful when called from tmux run-shell to avoid status-bar flash.
# --force-new: skip the switch lookup and always create a new AI window.

QUIET=false
FORCE_NEW=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        --force-new) FORCE_NEW=true; shift ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

_create_new_ai_window() {
    local tool workdir
    tool=$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null | cut -d= -f2)
    [ -z "$tool" ] && tool=claude
    workdir=$(tmux display-message -p '#{pane_current_path}')
    # Launch with interactive shell to ensure the tool runner is available
    tmux new-window -n "$tool" -c "$workdir" "zsh -ic \"${tool}r\""
}

if [[ "$FORCE_NEW" == true ]]; then
    _create_new_ai_window
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
