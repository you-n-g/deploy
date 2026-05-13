#!/bin/bash
# Stamp @last_visit on every pane in the target tmux window.

TARGET="${1:?usage: update_last_visit.sh TARGET}"

NOW=$(date +%s)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

pane_ids="$(tmux list-panes -t "$TARGET" -F '#{pane_id}' 2>/dev/null)" || exit 0
if [ -z "$pane_ids" ]; then
  exit 0
fi

while IFS= read -r pane_id; do
  [ -n "$pane_id" ] || continue
  tmux set -p -t "$pane_id" @last_visit "$NOW" 2>/dev/null || true
  "$SCRIPT_DIR/track_ai_agent_state.sh" visit "$pane_id"
done <<< "$pane_ids"
