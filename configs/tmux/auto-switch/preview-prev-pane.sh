#!/usr/bin/env bash
set -euo pipefail

# Show a live preview of one pane, refreshed every ~0.5s for a few seconds, then
# exit. Meant to run inside `display-popup -E` right after an auto-switch: the
# popup pops on the pane you just switched TO and shows the pane you switched
# FROM, so a glance tells you what the previous window was doing without
# switching back. Auto-closes when this command returns.
#
# With a title, the first line shows it (reverse video) and the rest shows the
# bottom of the pane, where its newest output is -- used by the task-done toast.
#
# usage: preview-prev-pane.sh <pane-id> [seconds] [title]

pane="${1:?usage: preview-prev-pane.sh <pane-id> [seconds] [title]}"
seconds="${2:-2}"
title="${3:-}"
interval="0.5"

# frames = seconds / interval, at least 1. Integer math in tenths of a second.
tenths=$(( ${seconds%.*} * 10 ))
frames=$(( tenths / 5 ))
(( frames >= 1 )) || frames=1

printf '\033[?25l'                      # hide cursor while animating
printf '\033[?7l'                       # no autowrap: clip long lines to the
                                        # popup width instead of wrapping them
trap 'printf "\033[?25h\033[?7h"' EXIT  # restore cursor + autowrap on exit

for (( i = 0; i < frames; i++ )); do
  # -e keeps colours; -N preserves trailing spaces so a line's background (e.g. a
  # full-width grey bar) reaches the edge as in the real window instead of being
  # trimmed. capture-pane leaves a line's SGR (e.g. a grey background) active at
  # the newline, which would bleed onto the next line here (unlike the real pane,
  # where each cell is independent), so reset SGR at every line end. A vanished
  # pane ends the preview early.
  frame="$(tmux capture-pane -e -N -p -t "$pane" 2>/dev/null | sed $'s/$/\033[0m/')" || break
  if [[ -n "$title" ]]; then
    rows="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_height}')"
    frame="$(printf '%s\n' "$frame" | tail -n "$(( rows - 1 ))")"
    printf '\033[H\033[J\033[7m%s\033[0m\n%s' "$title" "$frame"
  else
    printf '\033[H\033[J%s' "$frame"
  fi
  sleep "$interval"
done
