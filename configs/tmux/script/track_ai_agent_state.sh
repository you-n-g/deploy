#!/usr/bin/env bash

set -eu

state="${1:?usage: track_ai_agent_state.sh init|running|idle}"
now="$(date +%s)"

if [ -z "${TMUX_PANE:-}" ]; then
  exit 0
fi

window_id="$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}')"
tmux set-window-option -q -t "$window_id" @ai_agent_hook_state 1
tmux set-window-option -q -t "$window_id" @ai_agent_last_activity "$now"

is_window_visible() {
  [ "$(tmux display-message -p -t "$window_id" '#{window_active}')" = "1" ] \
    && [ "$(tmux display-message -p -t "$window_id" '#{session_attached}')" != "0" ]
}

case "$state" in
  init)
    tmux set-window-option -q -t "$window_id" @ai_agent_running 0
    tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
    ;;
  running)
    tmux set-window-option -q -t "$window_id" @ai_agent_running 1
    tmux set-window-option -q -t "$window_id" @ai_agent_last_start "$now"
    if is_window_visible; then
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
    fi
    ;;
  idle)
    tmux set-window-option -q -t "$window_id" @ai_agent_running 0
    tmux set-window-option -q -t "$window_id" @ai_agent_last_stop "$now"
    if is_window_visible; then
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
    else
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 1
    fi
    ;;
  *)
    echo "unknown AI agent state: $state" >&2
    exit 1
    ;;
esac
