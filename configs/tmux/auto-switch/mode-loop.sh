#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  mode-loop.sh [--list-option <tmux-option>] [--verbose]
  mode-loop.sh stop
  mode-loop.sh toggle [--list-option <tmux-option>] [--verbose]

Enable continuous auto-switch mode. The mode waits for a submitted AI pane
event, then switches to the first currently usable pane in the configured
sequence. It keeps looping until this process exits or a newer mode loop starts.
USAGE
}

list_option="@auto_switch_ranked_panes"
verbose=0

if [[ "${1:-}" == "stop" ]]; then
  mode_pid="$(tmux show-option -gqv @auto_switch_mode_pid 2>/dev/null || true)"
  tmux set-option -guq @auto_switch_mode_token 2>/dev/null || true
  tmux set-option -guq @auto_switch_mode_pid 2>/dev/null || true
  tmux set-option -guq @auto_switch_state 2>/dev/null || true
  tmux wait-for -S ai-agent-state 2>/dev/null || true
  if [[ -n "$mode_pid" ]] && kill -0 "$mode_pid" 2>/dev/null; then
    kill "$mode_pid" 2>/dev/null || true
  fi
  tmux display-message "auto-switch mode stopped"
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
    --list-option)
      list_option="${2:-}"
      shift 2
      ;;
    --verbose)
      verbose=1
      shift
      ;;
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
token="mode:$$:$(date +%s%N)"

existing_pid="$(tmux show-option -gqv @auto_switch_mode_pid 2>/dev/null || true)"
existing_token="$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)"
if [[ -n "$existing_pid" && -n "$existing_token" ]] && kill -0 "$existing_pid" 2>/dev/null; then
  tmux display-message "auto-switch mode already running: pid $existing_pid"
  exit 0
fi

cleanup() {
  if [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]]; then
    tmux set-option -guq @auto_switch_mode_token 2>/dev/null || true
    tmux set-option -guq @auto_switch_mode_pid 2>/dev/null || true
    tmux set-option -guq @auto_switch_state 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM HUP

tmux set-option -gq @auto_switch_mode_pid "$$"
tmux set-option -gq @auto_switch_mode_token "$token"
tmux set-option -gq @auto_switch_state mode-armed
tmux wait-for -S ai-agent-state 2>/dev/null || true
tmux display-message "auto-switch mode enabled"

while [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]]; do
  submitted_pane="$("$wait_script" --token-option @auto_switch_mode_token --token "$token" || true)"
  [[ -n "$submitted_pane" ]] || continue
  [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]] || exit 0

  tmux set-option -gq @auto_switch_state mode-switching
  if (( verbose )); then
    echo "auto-switch mode: submitted $submitted_pane"
  fi
  "$switch_script" --list-option "$list_option" >/dev/null 2>&1 || true
  tmux set-option -gq @auto_switch_state mode-armed
done
