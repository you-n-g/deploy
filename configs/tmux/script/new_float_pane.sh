#!/usr/bin/env bash
# The one place that creates floating panes: every script calls this instead of
# `tmux new-pane` (tests/test_float_panes.py rejects a direct call elsewhere).
#
# tmux 3.7b segfaults when a floating pane made in a zoomed window closes, by
# its process exiting, kill-pane, or after the window is unzoomed; the whole
# server goes down with every session. A float made first and zoomed over
# afterwards is fine. So a zoomed window is unzoomed before the pane is made.
# Background popups must not disturb the view instead: with --skip-if-zoomed
# nothing is made and the script exits 3; --zoomed-message TEXT does the same
# but first shows TEXT on the status line for 5 s, so the news still arrives.
#
# Remaining arguments go to `tmux new-pane` as given; the new pane id is printed.
#
# usage: new_float_pane.sh [--skip-if-zoomed | --zoomed-message TEXT] TARGET_PANE [new-pane args...]
set -euo pipefail

usage="usage: new_float_pane.sh [--skip-if-zoomed | --zoomed-message TEXT] TARGET_PANE [new-pane args...]"
skip_if_zoomed=0
zoomed_message=""
case "${1:-}" in
  --skip-if-zoomed) skip_if_zoomed=1; shift ;;
  --zoomed-message) skip_if_zoomed=1; zoomed_message="${2:?$usage}"; shift 2 ;;
esac
target="${1:?$usage}"
shift

if [[ "$(tmux display-message -p -t "$target" '#{window_zoomed_flag}')" == 1 ]]; then
  if (( skip_if_zoomed )); then
    [[ -z "$zoomed_message" ]] || tmux display-message -d 5000 -t "$target" "$zoomed_message"
    exit 3
  fi
  tmux resize-pane -Z -t "$target"
fi
exec tmux new-pane -t "$target" -P -F '#{pane_id}' "$@"
