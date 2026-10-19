#!/usr/bin/env bash
# Run a command in a focused floating pane covering TARGET_PANE's window; it
# closes when the command exits. Use this instead of display-popup when the
# program needs Esc: a popup receives keys before any key binding, so the
# CSI-u Escape shim (User900 in jump-history.conf) never reaches it and Esc is
# dropped, while a floating pane is a real pane and gets the translated Escape.
# A failed command holds the pane open so its error stays readable, like -EE.
#
# --skip-jump-history marks the pane @jump-history-skip so prefix+C-[ / C-]
# never record it. The mark is set in the same tmux command as new-pane, so it
# is already there when the pane-changed hook's jump_history.py reads it.
#
# --size WxH makes it W columns by H rows, centred, instead of the whole
# window (capped to the window): for a short list such as a session picker.
#
# usage: open_float_pane.sh [--skip-jump-history] [--size WxH] TARGET_PANE COMMAND [ARG...]
set -euo pipefail

usage="usage: open_float_pane.sh [--skip-jump-history] [--size WxH] TARGET_PANE COMMAND [ARG...]"
mark=()
size=""
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --skip-jump-history) mark=(';' set-option -p @jump-history-skip 1); shift ;;
    --size) size="${2:?$usage}"; shift 2 ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done
target="${1:?$usage}"
shift
(( $# > 0 )) || { echo "$usage" >&2; exit 2; }

read -r win_w win_h < <(tmux display-message -p -t "$target" '#{window_width} #{window_height}')
printf -v cmd '%q ' "$@"
cmd="$cmd; rc=\$?; if [ \$rc -ne 0 ]; then printf '\\nexited with %s, press Enter to close' \$rc; read -r _; fi"
# One column/row of border on each side.
w=$(( win_w - 2 )); h=$(( win_h - 2 ))
if [[ -n "$size" ]]; then
  [[ "$size" =~ ^([0-9]+)x([0-9]+)$ ]] || { echo "$usage" >&2; exit 2; }
  (( BASH_REMATCH[1] < w )) && w=${BASH_REMATCH[1]}
  (( BASH_REMATCH[2] < h )) && h=${BASH_REMATCH[2]}
fi
# Its output is the new pane id; run-shell would show it in a view pane.
"$(dirname -- "${BASH_SOURCE[0]}")/new_float_pane.sh" "$target" \
  -x "$w" -y "$h" -X "$(( (win_w - w) / 2 ))" -Y "$(( (win_h - h) / 2 ))" "$cmd" "${mark[@]}" >/dev/null
