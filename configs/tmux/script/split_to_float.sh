#!/usr/bin/env bash
# tmux 3.8 lifts a tiled pane into a float without replacing its process or ID.
# usage: split_to_float.sh PANE
set -euo pipefail

fail() { tmux display-message "split_to_float: $1"; exit 1; }
pane="$(tmux display-message -p -t "${1:?usage: split_to_float.sh PANE}" '#{pane_id}')"
[[ "$(tmux display-message -p -t "$pane" '#{window_zoomed_flag}')" != 1 ]] || tmux resize-pane -Z -t "$pane"
read -r window floating win_w win_h < <(tmux display-message -p -t "$pane" '#{window_id} #{pane_floating_flag} #{window_width} #{window_height}')
[[ "$floating" != 1 ]] || fail "已经是浮窗"
tiled="$(tmux list-panes -t "$window" -f '#{!=:#{pane_floating_flag},1}' -F x | wc -l)"
(( tiled > 1 )) || fail "这是窗口里唯一的分屏，变成浮窗后底下就没有 pane 了"

tmux break-pane -W -s "$pane" -x "$(( win_w / 2 ))" -y "$(( win_h / 2 ))" -X "$(( win_w / 2 ))" -Y 0
if ! tmux list-panes -t "$window" -F '#{@float_ai}' | grep -qx 1; then
  tmux set-option -pq -t "$pane" @float_ai 1
fi
