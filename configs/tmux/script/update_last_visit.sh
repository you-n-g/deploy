#!/bin/bash
# Stamp @last_visit on the current tmux window.

SESSION="$1"
WINDOW="$2"
NOW=$(date +%s)

tmux set -w -t "$SESSION:$WINDOW" @last_visit "$NOW" 2>/dev/null || true
tmux set -w -t "$SESSION:$WINDOW" @ai_agent_unread 0 2>/dev/null || true
