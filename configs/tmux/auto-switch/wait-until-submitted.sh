#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  wait-until-submitted.sh <mode-token>

Wait for the tmux AI state event stream. When an AI pane publishes a running or
pending event while it is the user's current pane, print that pane id and exit.
The running event also covers pending -> running transitions.

Exit quietly when <mode-token> no longer matches @auto_switch_mode_token.
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

token="${1:-}"
[[ -n "$token" ]] || { usage; exit 2; }
shift

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

is_current_token() {
  [[ "$(tmux show-option -gqv @auto_switch_mode_token 2>/dev/null || true)" == "$token" ]]
}

current_user_pane() {
  local client pane client_readonly control_mode activity best_pane="" best_activity=-1

  while IFS=$'\t' read -r client client_readonly control_mode pane activity; do
    [[ -n "$client" ]] || continue
    [[ "$client_readonly" == "1" || "$control_mode" == "1" ]] && continue
    [[ -n "$pane" ]] || continue
    [[ "$activity" =~ ^[0-9]+$ ]] || activity=0
    if (( activity > best_activity )); then
      best_activity="$activity"
      best_pane="$pane"
    fi
  done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}	#{pane_id}	#{client_activity}' 2>/dev/null || true)

  [[ -n "$best_pane" ]] && printf '%s\n' "$best_pane"
}

last_seq="$(tmux show-option -gqv @ai_agent_event_seq 2>/dev/null || true)"
[[ "$last_seq" =~ ^[0-9]+$ ]] || last_seq=0

while :; do
  tmux wait-for ai-agent-state
  is_current_token || exit 0

  seq="$(tmux show-option -gqv @ai_agent_event_seq 2>/dev/null || true)"
  [[ "$seq" =~ ^[0-9]+$ ]] || continue
  [[ "$seq" != "$last_seq" ]] || continue
  last_seq="$seq"

  event_pane="$(tmux show-option -gqv @ai_agent_event_pane 2>/dev/null || true)"
  event_state="$(tmux show-option -gqv @ai_agent_event_state 2>/dev/null || true)"
  event_client_pane="$(tmux show-option -gqv @ai_agent_event_client_pane 2>/dev/null || true)"
  case "$event_state" in
    running|pending) ;;
    *) continue ;;
  esac

  if [[ -z "$event_client_pane" ]]; then
    event_client_pane="$(current_user_pane 2>/dev/null || true)"
  fi
  [[ -n "$event_pane" ]] || continue
  [[ "$event_pane" == "$event_client_pane" ]] || continue

  printf '%s\n' "$event_pane"
  exit 0
done
