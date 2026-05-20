#!/usr/bin/env bash

set -euo pipefail

current="${1:-}"
if [ -z "$current" ]; then
  current="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi

marked="$(tmux display-message -p -t '{marked}' '#{pane_id}' 2>/dev/null || true)"
if [ -n "$marked" ] && [ "$marked" != "$current" ]; then
  tmux switch-client -t "$marked"
  exit 0
fi

switcher="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"
if [ -n "$switcher" ] && tmux display-message -p -t "$switcher" '#{pane_id}' >/dev/null 2>&1; then
  tmux switch-client -t "$switcher"
  exit 0
fi

tmux display-message "No marked pane or window-switcher pane"
exit 1
