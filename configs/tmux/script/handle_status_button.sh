#!/usr/bin/env bash

set -eu

button="${1:-}"
session="${2:-}"
path="${3:-$HOME}"
refresh_all_sessions=0

clear_buttons_expanded_overrides() {
  tmux list-sessions -F '#S' 2>/dev/null | while IFS= read -r session_name; do
    tmux set-option -qu -t "${session_name}:" @status-buttons-expanded 2>/dev/null || true
  done
}

set_buttons_expanded() {
  value="$1"
  tmux set-option -g @status-buttons-expanded "$value" >/dev/null
  clear_buttons_expanded_overrides
  refresh_all_sessions=1
}

case "$button" in
  aiw_*)
    tmux switch-client -t "@${button#aiw_}"
    ;;
  sb_k)
    tmux switch-client -t code
    ;;
  sb_l)
    tmux last-window
    ;;
  sb_s)
    tmux choose-window -Z
    ;;
  sb_more)
    set_buttons_expanded 1
    ;;
  sb_less)
    set_buttons_expanded 0
    ;;
  sb_g)
    tmux run-shell -b "cd '$path' && ~/deploy/configs/tmux/ai/tmuxg.sh --create-if-missing -q"
    ;;
  sb_mc)
    tmux run-shell -b "~/deploy/configs/tmux/ai/tmuxg.sh --force-new -q"
    ;;
  sb_cg)
    tmux run-shell -b "~/deploy/configs/tmux/ai/tmuxg.sh -A -q"
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

if [ "$refresh_all_sessions" -eq 1 ]; then
  tmux list-sessions -F '#S' 2>/dev/null | while IFS= read -r session_name; do
    "$HOME/deploy/configs/tmux/script/refresh_status_lines.sh" "$session_name"
  done
elif [ -n "$session" ]; then
  "$HOME/deploy/configs/tmux/script/refresh_status_lines.sh" "$session"
fi
