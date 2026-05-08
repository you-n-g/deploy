#!/bin/bash
# Stamp @last_visit on the current tmux window.

TARGET="${1:?usage: update_last_visit.sh TARGET}"

NOW=$(date +%s)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

window_id="$(tmux display-message -p -t "$TARGET" '#{window_id}' 2>/dev/null)" || exit 0
if [ -z "$window_id" ]; then
  exit 0
fi

tmux set -w -t "$window_id" @last_visit "$NOW" 2>/dev/null || true
"$SCRIPT_DIR/track_ai_agent_state.sh" visit "$window_id"
