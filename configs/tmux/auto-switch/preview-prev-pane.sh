#!/usr/bin/env bash
set -euo pipefail

# Show a live preview of one pane, refreshed every ~0.5s for a few seconds, then
# exit. Meant to run inside `display-popup -E` right after an auto-switch: the
# popup pops on the pane you just switched TO and shows the pane you switched
# FROM, so a glance tells you what the previous window was doing without
# switching back. Auto-closes when this command returns.
#
# usage: preview-prev-pane.sh <pane-id> [seconds]

pane="${1:?usage: preview-prev-pane.sh <pane-id> [seconds]}"
seconds="${2:-2}"
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
  # trimmed. A vanished pane ends the preview early.
  frame="$(tmux capture-pane -e -N -p -t "$pane" 2>/dev/null)" || break
  printf '\033[H\033[J%s' "$frame"
  sleep "$interval"
done
