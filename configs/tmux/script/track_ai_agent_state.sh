#!/usr/bin/env bash

set -eu

state="${1:?usage: track_ai_agent_state.sh init|running|idle|visit TARGET}"

target="${2:-${TMUX_PANE:?usage: track_ai_agent_state.sh init|running|idle|visit TARGET}}"
window_id="$(tmux display-message -p -t "$target" '#{window_id}')"

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
    if is_window_visible; then
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
    fi
    ;;
  idle)
    tmux set-window-option -q -t "$window_id" @ai_agent_running 0
    if is_window_visible; then
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
    else
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 1
    fi
    ;;
  visit)
    if [ -n "$(tmux display-message -p -t "$window_id" '#{@ai_agent_running}' 2>/dev/null)" ]; then
      tmux set-window-option -q -t "$window_id" @ai_agent_unread 0
    fi
    ;;
  *)
    echo "unknown AI agent state: $state" >&2
    exit 1
    ;;
esac

tmux refresh-client -S
