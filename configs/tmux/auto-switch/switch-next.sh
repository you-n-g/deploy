#!/usr/bin/env bash
set -euo pipefail

source "$HOME/deploy/configs/tmux/ai/lib.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  switch-next.sh [--controller <pane>] [--list-option <tmux-option>] [--verbose]

Read a ranked pane list from a tmux global option, switch the user's tmux
client(s) to the first currently usable AI pane.

The ranked list option is whitespace-separated pane ids. Default:
  @auto_switch_ranked_panes

If a controller pane is provided, that pane is excluded from the target
candidates. Otherwise no pane is excluded.
USAGE
}

controller=""
list_option="@auto_switch_ranked_panes"
verbose=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --controller)
      controller="${2:-}"
      shift 2
      ;;
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

if [[ -n "$controller" ]]; then
  controller="$(tmux display-message -p -t "$controller" '#{pane_id}' 2>/dev/null)" \
    && [[ -n "$controller" ]] \
    || { echo "controller pane does not resolve" >&2; exit 1; }
fi

ranked="$(tmux show-option -gqv "$list_option" 2>/dev/null || true)"
[[ -n "$ranked" ]] || { echo "No ranked panes in $list_option" >&2; exit 1; }

pane_exists() {
  tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1
}

is_usable_pane() {
  local pane="$1"
  local pane_pid running background pending

  [[ -z "$controller" || "$pane" != "$controller" ]] || return 1
  pane_exists "$pane" || return 1

  pane_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] || return 1
  _has_ai_proc "$pane_pid" || return 1

  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane" @ai_agent_background 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane" @ai_agent_pending 2>/dev/null || true)"
  [[ "$running" != "1" && "$background" != "1" && "$pending" != "1" ]]
}

target=""
for candidate in $ranked; do
  resolved="$(tmux display-message -p -t "$candidate" '#{pane_id}' 2>/dev/null || true)"
  [[ -n "$resolved" ]] || continue
  if is_usable_pane "$resolved"; then
    target="$resolved"
    break
  fi
done

if [[ -z "$target" ]]; then
  tmux display-message "auto-switch: no usable AI pane in ranked list"
  if (( verbose )); then
    echo "No usable AI pane in $list_option: $ranked"
  fi
  exit 1
fi

target_session="$(tmux display-message -p -t "$target" '#{session_name}')"
target_window_id="$(tmux display-message -p -t "$target" '#{window_id}')"
target_label="$(tmux display-message -p -t "$target" '#{session_name}:#{window_index}.#{pane_index}')"

while IFS=$'\t' read -r client readonly control_mode; do
  [[ -n "$client" ]] || continue
  [[ "$readonly" == "1" || "$control_mode" == "1" ]] && continue
  if ! tmux switch-client -c "$client" -t "$target_session:" 2>/dev/null; then
    tmux switch-client -t "$target_session:"
  fi
done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}')

tmux select-window -t "$target_window_id"
tmux select-pane -t "$target"

if (( verbose )); then
  echo "auto-switch: switched to $target_label ($target)"
fi
