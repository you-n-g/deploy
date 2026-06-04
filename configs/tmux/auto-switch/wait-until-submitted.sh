#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  wait-until-submitted.sh [--controller <pane>] [--token-option <tmux-option>] [--token <value>]

Wait for the tmux AI state event stream. When an AI pane changes from
non-running/non-pending to running or pending while it is the user's current
pane, print that pane id and exit.

If --controller is provided, that pane is ignored.
If --token-option and --token are provided, exit quietly when the token no
longer matches the tmux option.
USAGE
}

controller=""
token_option=""
token=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --controller)
      controller="${2:-}"
      shift 2
      ;;
    --token-option)
      token_option="${2:-}"
      shift 2
      ;;
    --token)
      token="${2:-}"
      shift 2
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

if [[ -n "$controller" ]]; then
  controller="$(tmux display-message -p -t "$controller" '#{pane_id}' 2>/dev/null)" \
    && [[ -n "$controller" ]] \
    || { echo "controller pane does not resolve" >&2; exit 2; }
fi

if [[ -n "$token_option" || -n "$token" ]]; then
  [[ -n "$token_option" && -n "$token" ]] || { echo "--token-option and --token must be used together" >&2; exit 2; }
fi

is_current_token() {
  [[ -z "$token_option" ]] || [[ "$(tmux show-option -gqv "$token_option" 2>/dev/null || true)" == "$token" ]]
}

current_user_pane() {
  local client pane readonly control_mode activity best_pane="" best_activity=-1

  while IFS=$'\t' read -r client readonly control_mode pane activity; do
    [[ -n "$client" ]] || continue
    [[ "$readonly" == "1" || "$control_mode" == "1" ]] && continue
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
  [[ -z "$controller" || "$event_pane" != "$controller" ]] || continue
  [[ "$event_pane" == "$event_client_pane" ]] || continue

  printf '%s\n' "$event_pane"
  exit 0
done
