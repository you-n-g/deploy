#!/usr/bin/env bash

set -euo pipefail

action="${1:-apply}"
target="${2:-}"

if [ -z "$target" ]; then
  target="$(tmux display-message -p '#{pane_id}')"
fi

pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"

show_window_option() {
  tmux show-options -wqv -t "$window_id" "$1" 2>/dev/null || true
}

apply_focus_size() {
  enabled="$(show_window_option @pane_focus_70)"
  [ "$enabled" = "1" ] || exit 0

  pane_count="$(tmux display-message -p -t "$pane_id" '#{window_panes}')"
  [ "$pane_count" -gt 1 ] || exit 0

  IFS=$'\t' read -r window_width window_height pane_width pane_height < <(
    tmux display-message -p -t "$pane_id" '#{window_width}	#{window_height}	#{pane_width}	#{pane_height}'
  )

  target_width=$(((window_width * 70 + 99) / 100))
  target_height=$(((window_height * 70 + 99) / 100))

  if [ "$pane_width" -lt "$target_width" ]; then
    tmux resize-pane -t "$pane_id" -x "$target_width"
  fi

  if [ "$pane_height" -lt "$target_height" ]; then
    tmux resize-pane -t "$pane_id" -y "$target_height"
  fi
}

enable_focus_mode() {
  saved_layout="$(tmux display-message -p -t "$window_id" '#{window_layout}')"
  tmux set-option -wq -t "$window_id" @pane_focus_70_saved_layout "$saved_layout"
  tmux set-option -wq -t "$window_id" @pane_focus_70 1
  tmux display-message "Pane 70% focus enabled for this window"
  apply_focus_size
}

disable_focus_mode() {
  tmux set-option -wq -t "$window_id" @pane_focus_70 0
  saved_layout="$(show_window_option @pane_focus_70_saved_layout)"

  if [ -n "$saved_layout" ]; then
    if tmux select-layout -t "$window_id" "$saved_layout"; then
      tmux set-option -wqu -t "$window_id" @pane_focus_70_saved_layout
      tmux display-message "Pane 70% focus disabled; restored previous layout"
    else
      tmux set-option -wqu -t "$window_id" @pane_focus_70_saved_layout
      tmux display-message "Pane 70% focus disabled; saved layout no longer matches this window"
    fi
  else
    tmux display-message "Pane 70% focus disabled"
  fi
}

case "$action" in
  apply)
    apply_focus_size
    ;;
  toggle)
    if [ "$(show_window_option @pane_focus_70)" = "1" ]; then
      disable_focus_mode
    else
      enable_focus_mode
    fi
    ;;
  *)
    echo "usage: pane_focus_70.sh [apply|toggle] [tmux-target]" >&2
    exit 2
    ;;
esac
