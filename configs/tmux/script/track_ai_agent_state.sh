#!/usr/bin/env bash

set -eu

state="${1:?usage: track_ai_agent_state.sh init|running|idle|visit TARGET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

target="${2:-${TMUX_PANE:?usage: track_ai_agent_state.sh init|running|idle|visit TARGET}}"
if ! pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')" || [ -z "$pane_id" ]; then
  if [ "$state" = "visit" ]; then
    exit 0
  fi
  exit 1
fi
window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"

ensure_ai_agent_attribute() {
  if [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]; then
    return
  fi

  local cmd
  printf -v cmd '%q %q' "$SCRIPT_DIR/generate_ai_window_attribute.sh" "$pane_id"
  tmux run-shell -b "$cmd"
}

reset_ai_agent_attribute() {
  if [ -n "${TMUX_AI_FORK_ATTRIBUTE:-}" ]; then
    tmux set-option -pq -t "$pane_id" @ai_agent_attribute "$TMUX_AI_FORK_ATTRIBUTE"
  else
    tmux set-option -pqu -t "$pane_id" @ai_agent_attribute 2>/dev/null || true
  fi
}

is_window_visible() {
  [ "$(tmux display-message -p -t "$window_id" '#{window_active}')" = "1" ] \
    && [ "$(tmux display-message -p -t "$window_id" '#{session_attached}')" != "0" ]
}

case "$state" in
  init)
    reset_ai_agent_attribute
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    ;;
  running)
    tmux set-option -pq -t "$pane_id" @ai_agent_running 1
    if is_window_visible; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    fi
    ;;
  idle)
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    if is_window_visible; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    fi
    ensure_ai_agent_attribute
    ;;
  visit)
    if [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null)" ]; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    fi
    ;;
  *)
    echo "unknown AI agent state: $state" >&2
    exit 1
    ;;
esac

# Hooks can run while a client is attaching/detaching, where tmux may have no
# current client to refresh. State updates above are the meaningful work here.
tmux refresh-client -S 2>/dev/null || true
