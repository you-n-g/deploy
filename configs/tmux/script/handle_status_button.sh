#!/usr/bin/env bash

set -eu

button="${1:-}"
session="${2:-}"
path="${3:-$HOME}"

set_buttons_expanded() {
  value="$1"
  if [ -n "$session" ]; then
    tmux set-option -t "${session}:" @status-buttons-expanded "$value" >/dev/null
  else
    tmux set-option -g @status-buttons-expanded "$value" >/dev/null
  fi
}

case "$button" in
  sb_more)
    set_buttons_expanded 1
    ;;
  sb_less)
    set_buttons_expanded 0
    ;;
  sb_g)
    tmux run-shell -b "cd '$path' && ~/deploy/configs/tmux/ai/switch_to_or_create.sh -q"
    ;;
  sb_cg)
    tmux display-popup -E -w 100% -h 100% "~/deploy/configs/tmux/ai/tmuxg.sh"
    ;;
  sb_t)
    tmux run-shell -b "~/deploy/configs/tmux/ai/send_current_target_to_ai.sh -q"
    ;;
  sb_ct)
    tmux run-shell -b "~/deploy/configs/tmux/ai/send_current_target_to_ai.sh -A -q"
    ;;
  sb_mf)
    tmux run-shell -b "~/deploy/configs/tmux/ai/fork_ai_session.sh -q"
    ;;
  sb_ml)
    tmux run-shell -b "~/deploy/configs/tmux/ai/switch_to_last_ai_window.sh -q"
    ;;
  sb_cc)
    tmux run-shell -b "~/deploy/helper_scripts/bin/c"
    ;;
  *)
    tmux display-message "Unknown status button: ${button}"
    ;;
esac

if [ -n "$session" ]; then
  "$HOME/deploy/configs/tmux/script/refresh_status_lines.sh" "$session"
fi
