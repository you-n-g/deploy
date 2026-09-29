#!/usr/bin/env bash
# Run a command in a focused floating pane covering TARGET_PANE's window; it
# closes when the command exits. Use this instead of display-popup when the
# program needs Esc: a popup receives keys before any key binding, so the
# CSI-u Escape shim (User900 in jump-history.conf) never reaches it and Esc is
# dropped, while a floating pane is a real pane and gets the translated Escape.
# A failed command holds the pane open so its error stays readable, like -EE.
#
# usage: open_float_pane.sh TARGET_PANE COMMAND [ARG...]
set -euo pipefail

target="${1:?usage: open_float_pane.sh TARGET_PANE COMMAND [ARG...]}"
shift
(( $# > 0 )) || { echo "usage: open_float_pane.sh TARGET_PANE COMMAND [ARG...]" >&2; exit 2; }

read -r win_w win_h < <(tmux display-message -p -t "$target" '#{window_width} #{window_height}')
printf -v cmd '%q ' "$@"
cmd="$cmd; rc=\$?; if [ \$rc -ne 0 ]; then printf '\\nexited with %s, press Enter to close' \$rc; read -r _; fi"
# One column/row of border on each side.
tmux new-pane -t "$target" -x "$(( win_w - 2 ))" -y "$(( win_h - 2 ))" -X 1 -Y 1 "$cmd"
