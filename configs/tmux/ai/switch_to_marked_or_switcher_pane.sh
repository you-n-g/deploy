#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_SCRIPT_DIR="$SCRIPT_DIR/../script"

pane_exists() {
  tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$1"
}

current="${1:-}"
if [ -z "$current" ]; then
  current="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi

marked="$(tmux display-message -p -t '{marked}' '#{pane_id}' 2>/dev/null || true)"
switcher="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"

if [ -n "$marked" ] && [ "$marked" != "$current" ]; then
  tmux switch-client -t "$marked"
  "$TMUX_SCRIPT_DIR/refresh_terminal_title.sh" >/dev/null 2>&1 || true
  exit 0
fi

if [ -n "$switcher" ] && pane_exists "$switcher"; then
  tmux switch-client -t "$switcher"
  "$TMUX_SCRIPT_DIR/refresh_terminal_title.sh" >/dev/null 2>&1 || true
  exit 0
fi

if [ -n "$switcher" ]; then
  "$SCRIPT_DIR/set_window_switcher_pane.sh" cleanup
fi

tmux display-message "No pane to switch back to"
exit 0
