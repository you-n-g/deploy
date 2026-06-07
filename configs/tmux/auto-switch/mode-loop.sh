#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  mode-loop.sh
  mode-loop.sh stop
  mode-loop.sh toggle

Enable continuous auto-switch mode. The mode waits for a submitted AI pane
event, then switches to the first currently usable pane in the auto-switch
sequence. It keeps looping until this process exits or a newer mode loop starts.
USAGE
}

refresh_status() {
  tmux refresh-client -S 2>/dev/null || true
}

set_status_symbol() {
  tmux set-option -gq @auto_switch_status_symbol " ○"
}

clear_status_symbol() {
  tmux set-option -guq @auto_switch_status_symbol 2>/dev/null || true
}

clear_mode_state() {
  tmux set-option -guq @auto_switch_mode_token 2>/dev/null || true
  tmux set-option -guq @auto_switch_mode_pid 2>/dev/null || true
  clear_status_symbol
  refresh_status
}

if [[ "${1:-}" == "stop" ]]; then
  mode_pid="$(tmux show-option -gqv @auto_switch_mode_pid 2>/dev/null || true)"
  clear_mode_state
  tmux wait-for -S ai-agent-state 2>/dev/null || true
  if [[ -n "$mode_pid" ]] && kill -0 "$mode_pid" 2>/dev/null; then
    kill "$mode_pid" 2>/dev/null || true
  fi
  exit 0
fi

if [[ "${1:-}" == "toggle" ]]; then
  mode_pid="$(tmux show-option -gqv @auto_switch_mode_pid 2>/dev/null || true)"
  mode_token="$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)"
  if [[ -n "$mode_pid" && -n "$mode_token" ]] && kill -0 "$mode_pid" 2>/dev/null; then
    "$0" stop
    exit 0
  fi
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
wait_script="$script_dir/wait-until-submitted.sh"
switch_script="$script_dir/switch-next.sh"
token="mode:$$:$(date +%s)"

existing_pid="$(tmux show-option -gqv @auto_switch_mode_pid 2>/dev/null || true)"
existing_token="$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)"
if [[ -n "$existing_pid" && -n "$existing_token" ]] && kill -0 "$existing_pid" 2>/dev/null; then
  tmux display-message "auto-switch mode already running: pid $existing_pid"
  exit 0
fi

cleanup() {
  if [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]]; then
    clear_mode_state
  fi
}
trap cleanup EXIT INT TERM HUP

tmux set-option -gq @auto_switch_mode_pid "$$"
tmux set-option -gq @auto_switch_mode_token "$token"
set_status_symbol
refresh_status
tmux wait-for -S ai-agent-state 2>/dev/null || true

while [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]]; do
  submitted_pane="$("$wait_script" "$token" || true)"
  [[ -n "$submitted_pane" ]] || continue
  [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]] || exit 0

  "$switch_script" >/dev/null 2>&1 || true
done
