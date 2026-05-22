#!/usr/bin/env bash

set -euo pipefail

action="${1:-set}"
target="${2:-}"

pane_exists() {
  tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$1"
}

resolve_pane_id() {
  local pane_id target="${1:?usage: resolve_pane_id TARGET}"

  pane_id="$(tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null || true)"
  [ -n "$pane_id" ] && pane_exists "$pane_id" || return 1
  printf '%s\n' "$pane_id"
}

clear_switcher() {
  tmux set-option -guq @tma_window_switcher_pane 2>/dev/null || true
}

case "$action" in
  set)
    if [ -z "$target" ]; then
      target="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
    fi
    [ -n "$target" ] || exit 1
    target="$(resolve_pane_id "$target")"

    clear_switcher
    tmux set-option -gq @tma_window_switcher_pane "$target"
    ;;
  cleanup)
    old="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"
    if [ -n "$old" ] && ! pane_exists "$old"; then
      tmux set-option -guq @tma_window_switcher_pane 2>/dev/null || true
    fi
    ;;
  clear)
    clear_switcher
    ;;
  *)
    echo "usage: set_window_switcher_pane.sh [set [target]|cleanup|clear]" >&2
    exit 2
    ;;
esac
