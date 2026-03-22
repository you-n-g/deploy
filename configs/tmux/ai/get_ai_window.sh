#!/bin/bash
# Centralized script to find the most recently active AI window
# Usage: ./get_ai_window.sh [-i] [-p] [session_name]
# -i: return window_id instead of window_name
# -p: print the AI window name pattern and exit

AI_WINDOW_PATTERN="(gemini|codex|claude)"

RETURN_ID=false

while getopts ":ip" opt; do
    case $opt in
        i) RETURN_ID=true ;;
        p) echo "$AI_WINDOW_PATTERN"; exit 0 ;;
        *) echo "Usage: $0 [-i] [-p] [session_name]" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

SESSION=${1:-$(tmux display-message -p '#S' 2>/dev/null)}

if [[ -z "$SESSION" ]]; then
    exit 1
fi

# List windows in the session, filter for AI windows, sort by activity
# Format: name activity id
RESULT=$(tmux list-windows -t "$SESSION" -F '#{window_name} #{window_activity} #{window_id}' 2>/dev/null |
    grep -E "^${AI_WINDOW_PATTERN} " |
    sort -k2,2nr |
    head -n 1)

if [[ -z "$RESULT" ]]; then
    exit 1
fi

if [ "$RETURN_ID" = true ]; then
    echo "$RESULT" | awk '{print $3}'
else
    echo "$RESULT" | awk '{print $1}'
fi
