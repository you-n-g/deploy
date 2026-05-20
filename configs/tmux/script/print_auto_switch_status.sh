#!/usr/bin/env bash

set -eu

filter="${1:-}"
case "$filter" in
  ""|running|unread|idle)
    ;;
  *)
    echo "usage: print_auto_switch_status.sh [running|unread|idle]" >&2
    exit 2
    ;;
esac

switcher="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"
if [ -z "$switcher" ]; then
  exit 0
fi

if tmux display-message -p -t "$switcher" '#{pane_id}' >/dev/null 2>&1; then
  running="$(tmux show -pv -t "$switcher" @ai_agent_running 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$switcher" @ai_agent_unread 2>/dev/null || true)"

  if [ "$running" = "1" ]; then
    state="running"
    symbol="●"
  elif [ "$unread" = "1" ]; then
    state="unread"
    symbol="◉"
  else
    state="idle"
    symbol="○"
  fi

  if [ -z "$filter" ]; then
    printf '%s\n' "$symbol"
  elif [ "$filter" = "$state" ]; then
    printf ' %s\n' "$symbol"
  fi
else
  tmux set-option -guq @tma_window_switcher_pane 2>/dev/null || true
fi
