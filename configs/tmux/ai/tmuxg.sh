#!/bin/bash
# Select and switch to a tmux window for AI tools (gemini, codex, etc.)
# Usage: tmuxg [tool_pattern]
# Default pattern matches both gemini and codex

PATTERN=${1:-"(gemini|codex)"}

# Get the list of windows matching the pattern, sorted by last activity
LIST=$(tmux list-windows -a -F '#{window_activity} #{session_name}:#{window_index} #{window_name}' | grep -E " ${PATTERN}$" | sort -nr | cut -d' ' -f2-)

if [[ -z "$LIST" ]]; then
    echo "No windows matching '${PATTERN}' found."
    exit 0
fi

# Use fzf to select a window
SELECTED=$(echo "$LIST" | fzf \
    --reverse \
    --header "Select an AI window (Enter to switch)" \
    --preview 'tmux capture-pane -ept {1}' \
    --preview-window 'up:70%,follow')

# Exit if nothing was selected
[[ -z "$SELECTED" ]] && exit 0

# Extract the target (session:window_index)
TARGET=$(echo "$SELECTED" | cut -d' ' -f1)

if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$TARGET"
else
    # Outside tmux: attach to session and select window
    SESSION="${TARGET%%:*}"
    tmux attach-session -t "$SESSION" \; select-window -t "$TARGET"
fi
