#!/usr/bin/env bash

set -eu

button="${1:-}"
session="${2:-}"
path="${3:-$HOME}"

case "$button" in
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
