#!/usr/bin/env bash
# Sink a floating pane into its own window as a split, next to the tiled pane
# that was active before it. join-pane does this natively and the process
# keeps running. The pane stops being the window's @float_ai pane.
#
# side-by-side / stacked name the arrangement, as in join_previous.sh.
#
# usage: float_to_split.sh PANE side-by-side|stacked
set -euo pipefail

fail() { tmux display-message "float_to_split: $1"; exit 1; }

pane="$(tmux display-message -p -t "${1:?usage: float_to_split.sh PANE side-by-side|stacked}" '#{pane_id}')"
case "${2:-}" in
  side-by-side) split=-h ;;
  stacked) split=-v ;;
  *) echo "usage: float_to_split.sh PANE side-by-side|stacked" >&2; exit 2 ;;
esac
window="$(tmux display-message -p -t "$pane" '#{window_id}')"
# In a zoomed window tmux reports floating panes with pane_floating_flag 0, and
# the zoom also hides the split the pane would land in: unzoom first.
[[ "$(tmux display-message -p -t "$window" '#{window_zoomed_flag}')" != 1 ]] || tmux resize-pane -Z -t "$window"
[[ "$(tmux display-message -p -t "$pane" '#{pane_floating_flag}')" == 1 ]] || fail "不是浮窗"

# The tiled pane the float sat over: the window's last active one if tiled,
# otherwise the first tiled pane.
target="$(tmux list-panes -t "$window" -f '#{!=:#{pane_floating_flag},1}' \
  -F '#{pane_last} #{pane_id}' | sort -r | awk 'NR == 1 { print $2 }')"
[[ -n "$target" ]] || fail "窗口里没有分屏可以并进去"

tmux join-pane "$split" -s "$pane" -t "$target"
tmux set-option -pqu -t "$pane" @float_ai
