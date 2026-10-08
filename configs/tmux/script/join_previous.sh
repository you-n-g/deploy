#!/usr/bin/env bash
# Move PANE into the window of the client's previously visited pane in another
# window -- the same "previous" as prefix + C-l and C-[ (jump_history.py), so
# one rule covers both same-session and cross-session joins. ORIENTATION picks
# the split: side-by-side or stacked. The moved pane ends up focused.
#
# usage: join_previous.sh SOCKET CLIENT PANE side-by-side|stacked
set -euo pipefail

usage="usage: join_previous.sh SOCKET CLIENT PANE side-by-side|stacked"
socket="${1:?$usage}"
client="${2:?$usage}"
pane="${3:?$usage}"
case "${4:?$usage}" in
  side-by-side) split="-h" ;;
  stacked)      split="-v" ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

target="$(python3 "$(dirname "${BASH_SOURCE[0]}")/jump_history.py" --socket "$socket" --other-window previous "$client")"
target_pane="$(tmux -S "$socket" display-message -p -t "$target" '#{pane_id}')"
# Switch first: when PANE is the last one of its session, moving it destroys
# that session, which would detach a client still showing it.
tmux -S "$socket" switch-client -c "$client" -t "$target_pane"
# No -d: the moved pane becomes the active one in the target window.
tmux -S "$socket" join-pane "$split" -s "$pane" -t "$target_pane"
