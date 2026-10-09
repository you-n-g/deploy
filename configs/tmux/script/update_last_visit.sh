#!/bin/bash
# Stamp @last_visit on the target tmux pane.

TARGET="${1:?usage: update_last_visit.sh TARGET}"

NOW=$(date +%s)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

pane_id="$(tmux display-message -p -t "$TARGET" '#{pane_id}' 2>/dev/null)" || exit 0
if [ -z "$pane_id" ]; then
  exit 0
fi

# A visit is a pane some attached client is showing. The hooks also fire for a
# select-pane / select-window in a session nobody is looking at (a script
# reaching into another session, a window closing in a background session);
# counting those would make last_ai_pane.sh pick a pane the user never saw and
# clear its unread mark.
tmux list-clients -F '#{pane_id}' | grep -qxF "$pane_id" || exit 0

tmux set -p -t "$pane_id" @last_visit "$NOW" 2>/dev/null || true
AI_AGENT_STATE_SOURCE="tmux-visit-hook" "$SCRIPT_DIR/track_ai_agent_state.sh" visit "$pane_id"
