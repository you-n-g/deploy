#!/bin/bash
# Stamp @last_visit on the target tmux pane.

TARGET="${1:?usage: update_last_visit.sh TARGET}"

NOW=$(date +%s)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

pane_id="$(tmux display-message -p -t "$TARGET" '#{pane_id}' 2>/dev/null)" || exit 0
if [ -z "$pane_id" ]; then
  exit 0
fi

tmux set -p -t "$pane_id" @last_visit "$NOW" 2>/dev/null || true
"$SCRIPT_DIR/track_ai_agent_state.sh" visit "$pane_id"
