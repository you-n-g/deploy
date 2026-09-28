#!/usr/bin/env bash
# Task-done toast: float a live preview of an AI pane that just finished a turn
# out of sight over the window the user is looking at, top-right, ~45% of the
# window, for a few seconds. A floating pane made with new-pane -d, like the
# auto-switch preview, so keyboard focus stays where it is; it closes itself
# when preview-prev-pane.sh returns.
#
# usage: show_done_toast.sh DONE_PANE HOST_PANE
set -euo pipefail

done_pane="${1:?usage: show_done_toast.sh DONE_PANE HOST_PANE}"
host_pane="${2:?usage: show_done_toast.sh DONE_PANE HOST_PANE}"
preview="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../auto-switch" && pwd)/preview-prev-pane.sh"

# One toast at a time: a newer completion replaces the one still showing.
while read -r pane tag; do
  [[ "$tag" == "1" ]] && tmux kill-pane -t "$pane"
done < <(tmux list-panes -a -F '#{pane_id} #{@ai_done_toast}')

# prefix + M-n jumps here after the toast is gone.
tmux set-option -g @last_done_toast_pane "$done_pane"

title="$(tmux display-message -p -t "$done_pane" \
  '✓ 完成  #{session_name}:#{window_index}.#{pane_index}  #{window_name}#{?@ai_agent_attribute, — #{@ai_agent_attribute},}')"
read -r win_w win_h < <(tmux display-message -p -t "$host_pane" '#{window_width} #{window_height}')
pw=$(( win_w * 45 / 100 )); ph=$(( win_h * 45 / 100 ))
px=$(( win_w - pw - 1 )); py=1
printf -v cmd '%q ' "$preview" "$done_pane" 5 "$title"
toast="$(tmux new-pane -d -t "$host_pane" -x "$pw" -y "$ph" -X "$px" -Y "$py" -P -F '#{pane_id}' "$cmd")"
# Green border: apart from the grey pane borders and the cyan switch preview.
tmux set-option -p -t "$toast" @ai_done_toast 1 \; \
  set-option -p -t "$toast" pane-border-style 'fg=colour46,bold'
