#!/bin/bash
# Stamp @last_visit on the current tmux window.

SESSION="$1"
WINDOW="$2"
NOW=$(date +%s)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

tmux set -w -t "$SESSION:$WINDOW" @last_visit "$NOW" 2>/dev/null || true
"$SCRIPT_DIR/track_ai_agent_state.sh" visit "$SESSION:$WINDOW"
