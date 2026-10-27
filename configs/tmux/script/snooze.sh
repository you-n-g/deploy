#!/usr/bin/env bash
# Snooze PANE: pending for a while, then back to idle on its own. For a pane
# that matters but has stalled for now: it keeps its place in the auto-switch
# sequence, auto-switch skips it while pending, and when the time is up it is
# released like any other pending (unread when out of sight).
#
# The reason "睡到 HH:MM" (with the date when not today) is the record: the
# timer, a background tmux job, releases the pane only if its reason is still
# exactly that, so a snooze cleared, rewritten or replaced in the meantime is
# left alone. Like every pending, it does not survive a tmux server restart.
#
# prefix + M-p . (half an hour) / 1 / 2 / 3 / 4 / s.
#
# usage: snooze.sh PANE HOURS      (HOURS may be fractional: 0.5, 1.5)
#        snooze.sh --wake PANE REASON
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
usage="usage: snooze.sh PANE HOURS | snooze.sh --wake PANE REASON"

if [[ "${1:-}" == "--wake" ]]; then
  pane="${2:?$usage}"
  reason="${3:?$usage}"
  [[ "$(tmux show-option -pqv -t "$pane" @ai_agent_pending 2>/dev/null)" == "$reason" ]] || exit 0
  AI_AGENT_STATE_SOURCE=snooze-wake exec "$script_dir/track_ai_agent_state.sh" wake "$pane"
fi

pane="$(tmux display-message -p -t "${1:?$usage}" '#{pane_id}')"
hours="${2:?$usage}"
[[ "$hours" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { tmux display-message "snooze: not a number of hours: $hours"; exit 1; }
seconds="$(awk -v h="$hours" 'BEGIN { printf "%d", h * 3600 }')"
(( seconds > 0 )) || { tmux display-message "snooze: needs more than 0 hours"; exit 1; }

wake_at=$(( $(date +%s) + seconds ))
if [[ "$(date -d "@$wake_at" +%F)" == "$(date +%F)" ]]; then
  reason="睡到 $(date -d "@$wake_at" +%H:%M)"
else
  reason="睡到 $(date -d "@$wake_at" '+%m-%d %H:%M')"
fi

AI_AGENT_STATE_SOURCE="${AI_AGENT_STATE_SOURCE:-snooze}" \
  "$script_dir/track_ai_agent_state.sh" pending "$pane" "$reason"
printf -v wake '%q ' "$script_dir/snooze.sh" --wake "$pane" "$reason"
tmux run-shell -b "sleep $seconds; $wake"
