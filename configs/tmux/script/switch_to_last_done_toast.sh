#!/usr/bin/env bash
# Switch to the pane the most recent task-done toast showed, recorded by
# show_done_toast.sh. The toast itself is usually gone by then.
set -euo pipefail

pane="$(tmux show-option -gqv @last_done_toast_pane)"
if [[ -z "$pane" ]]; then
  tmux display-message "No task-done toast has been shown yet"
  exit 1
fi
if ! tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
  tmux display-message "Last task-done toast pane is gone: $pane"
  exit 1
fi
tmux switch-client -t "$pane"
tmux select-window -t "$pane"
tmux select-pane -t "$pane"
