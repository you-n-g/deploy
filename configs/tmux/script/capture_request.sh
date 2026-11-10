#!/usr/bin/env bash
# The capture request typed into an AI's prompt for TARGET (prefix t a / g / l /
# L / s / i, prefix t c, the nvim AI helper):
#   请capture我的Tmux的这个pane[session:window.pane]（窗口 <name>，pane %<id>）的内容
# Only the tmux target sits in the brackets, so an agent can pass it to
# capture-pane as it is; the window name and pane id follow for the reader, and
# the id still finds the pane after windows are renumbered.
#
# usage: capture_request.sh [-S SOCKET] TARGET
set -euo pipefail

socket=()
if [[ "${1:-}" == -S ]]; then socket=(-S "${2:?usage: capture_request.sh [-S SOCKET] TARGET}"); shift 2; fi
target="${1:?usage: capture_request.sh [-S SOCKET] TARGET}"
IFS=$'\t' read -r position name id < <(tmux "${socket[@]}" display-message -p -t "$target" \
  '#{session_name}:#{window_index}.#{pane_index}	#{window_name}	#{pane_id}')
printf '请capture我的Tmux的这个pane[%s]（窗口 %s，pane %s）的内容' "$position" "$name" "$id"
