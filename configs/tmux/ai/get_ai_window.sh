#!/bin/bash
# Centralized script to find the most recently active AI window (gemini or codex)
# Usage: ./get_ai_window.sh [session_name] [--id]
# --id: return window_id instead of window_name

SESSION=$1
RETURN_ID=false

# Handle arguments
if [[ "$1" == "--id" ]]; then
    RETURN_ID=true
    SESSION=""
fi
if [[ "$2" == "--id" ]]; then
    RETURN_ID=true
fi

# Default session to current if not provided
if [[ -z "$SESSION" ]]; then
    SESSION=$(tmux display-message -p '#S' 2>/dev/null)
fi

if [[ -z "$SESSION" ]]; then
    exit 1
fi

# List windows in the session, filter for gemini or codex, sort by activity
# Format: name activity id
RESULT=$(tmux list-windows -t "$SESSION" -F '#{window_name} #{window_activity} #{window_id}' 2>/dev/null | 
    grep -E '^(gemini|codex) ' | 
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
