#!/usr/bin/env bash
# Submit what is typed in PANE (Enter) without the auto-switch loop moving on.
# The loop (mode-loop.sh) switches away when the current pane submits; this
# marks PANE first, and the loop skips the next submit it sees from PANE within
# 30 s (bounded, so a mark whose Enter submitted nothing -- an empty prompt --
# does not swallow a later real submit). Without the loop it is a plain Enter.
# prefix a e.
#
# usage: submit-stay.sh PANE
set -euo pipefail

pane="$(tmux display-message -p -t "${1:?usage: submit-stay.sh PANE}" '#{pane_id}')"
if [[ -n "$(tmux show-option -gqv @auto_switch_mode_pid)" ]]; then
  tmux set-option -pq -t "$pane" @auto_switch_stay_until "$(( $(date +%s) + 30 ))"
fi
tmux send-keys -t "$pane" Enter
