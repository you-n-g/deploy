#!/usr/bin/env bash

set -eu

filter="${1:-}"
case "$filter" in
  ""|active|armed)
    ;;
  *)
    echo "usage: print_auto_switch_status.sh [active|armed]" >&2
    exit 2
    ;;
esac

switcher="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"
if [ -z "$switcher" ]; then
  exit 0
fi

switcher="$(tmux display-message -p -t "$switcher" '#{pane_id}' 2>/dev/null || true)"
if [ -z "$switcher" ]; then
  tmux set-option -guq @tma_window_switcher_pane 2>/dev/null || true
  tmux set-option -guq @auto_switch_state 2>/dev/null || true
  exit 0
fi

state="$(tmux show-option -gqv @auto_switch_state 2>/dev/null || true)"
running="$(tmux show -pv -t "$switcher" @ai_agent_running 2>/dev/null || true)"

has_watcher=0
while read -r _pid cmd; do
  case "$cmd" in
    *"/wait-submit.sh"* )
      case "$cmd" in
        *"--controller ${switcher}"* ) has_watcher=1; break ;;
      esac
      ;;
  esac
done < <(ps -axo pid=,args=)

if [ "$state" = "switching" ] || [ "$state" = "rerank" ]; then
  status="active"
  symbol="●"
elif [ "$has_watcher" = "1" ]; then
  status="armed"
  symbol="○"
elif [ "$state" = "armed" ]; then
  tmux set-option -guq @auto_switch_state 2>/dev/null || true
  exit 0
elif [ "$running" = "1" ] && [ -n "$state" ]; then
  status="active"
  symbol="●"
else
  tmux set-option -guq @auto_switch_state 2>/dev/null || true
  exit 0
fi

if [ -z "$filter" ]; then
  printf ' %s\n' "$symbol"
elif [ "$filter" = "$status" ]; then
  printf ' %s\n' "$symbol"
fi
