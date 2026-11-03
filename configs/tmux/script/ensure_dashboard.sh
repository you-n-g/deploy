#!/usr/bin/env bash
# Go to the dashboard window (the dashboard skill's Textual TUI), wherever it
# runs; with none open, start one in PANE's session through the skill's own
# launch.sh. prefix k D.
#
# Found by the window name `dashboard`, the name launch.sh gives it. A window
# in any session counts: the dashboard is one app, a second copy would only
# repeat its fetches.
#
# usage: ensure_dashboard.sh PANE
set -euo pipefail

pane="${1:?usage: ensure_dashboard.sh PANE}"
launch="$HOME/.claude/skills/dashboard/scripts/launch.sh"

window="$(tmux list-windows -a -F '#{session_name} #{window_id} #{window_name}' | awk '$3 == "dashboard" { print $1, $2; exit }')"
if [[ -n "$window" ]]; then
  read -r session window_id <<< "$window"
  tmux switch-client -t "=$session"
  tmux select-window -t "$window_id"
  exit 0
fi
if ! output="$(TMUX_PANE="$pane" "$launch" 2>&1)"; then
  tmux display-message "dashboard: $output"
  exit 1
fi
