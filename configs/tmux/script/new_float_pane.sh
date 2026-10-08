#!/usr/bin/env bash
# The one place that creates floating panes: every script calls this instead of
# `tmux new-pane` (tests/test_float_panes.py rejects a direct call elsewhere).
#
# tmux 3.7b segfaults when a floating pane made in a zoomed window closes, by
# its process exiting, kill-pane, or after the window is unzoomed; the whole
# server goes down with every session. A float made first and zoomed over
# afterwards is fine. So a zoomed window is unzoomed before the pane is made,
# or, with --skip-if-zoomed (background popups that must not disturb the
# view), nothing is made and the script exits 3.
#
# Remaining arguments go to `tmux new-pane` as given; the new pane id is printed.
#
# usage: new_float_pane.sh [--skip-if-zoomed] TARGET_PANE [new-pane args...]
set -euo pipefail

usage="usage: new_float_pane.sh [--skip-if-zoomed] TARGET_PANE [new-pane args...]"
skip_if_zoomed=0
if [[ "${1:-}" == "--skip-if-zoomed" ]]; then
  skip_if_zoomed=1
  shift
fi
target="${1:?$usage}"
shift

if [[ "$(tmux display-message -p -t "$target" '#{window_zoomed_flag}')" == 1 ]]; then
  (( skip_if_zoomed == 0 )) || exit 3
  tmux resize-pane -Z -t "$target"
fi
exec tmux new-pane -t "$target" -P -F '#{pane_id}' "$@"
