#!/bin/bash

# Switch to the most recent 'gemini' or 'codex' window in the CURRENT session.
# If neither exists, create a new one based on PREFERRED_AI_TOOL.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TARGET_WINDOW=$("$SCRIPT_DIR/get_ai_window.sh" --id)

if [ -n "$TARGET_WINDOW" ]; then
    tmux select-window -t "$TARGET_WINDOW"
else
    # 1. Try to get TMUX_AI_TOOL from tmux global environment
    # 2. Fallback to current shell environment
    # 3. Default to 'gemini'
    TOOL=$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null | cut -d= -f2)
    if [ -z "$TOOL" ]; then
        TOOL=gemini
    fi
    
    # Launch with interactive shell to ensure the tool runner is available
    tmux new-window -n "$TOOL" "zsh -ic \"${TOOL}r\""
fi
