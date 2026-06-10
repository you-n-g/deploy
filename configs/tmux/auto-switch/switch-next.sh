#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/home/xiaoyang/deploy/configs/tmux/ai/lib.sh
source "$HOME/deploy/configs/tmux/ai/lib.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  switch-next.sh [--skip-pane TARGET]

Read a ranked pane list from a tmux global option, switch the user's tmux
client(s) to the first currently usable AI pane.

The ranked list option is whitespace-separated pane ids. Default:
  @auto_switch_ranked_panes
USAGE
}

ranked_option="@auto_switch_ranked_panes"
skip_pane_target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-pane)
      skip_pane_target="${2:?--skip-pane requires a tmux pane target}"
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

ranked="$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)"
[[ -n "$ranked" ]] || { echo "No ranked panes in $ranked_option" >&2; exit 1; }

pane_exists() {
  tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1
}

is_usable_pane() {
  local pane="$1"
  local pane_pid running background pending

  pane_exists "$pane" || return 1

  pane_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] || return 1
  _has_ai_proc "$pane_pid" || return 1

  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane" @ai_agent_background 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane" @ai_agent_pending 2>/dev/null || true)"
  [[ "$running" != "1" && "$background" != "1" && "$pending" != "1" ]]
}

skip_pane_id=""
if [[ -n "$skip_pane_target" ]]; then
  skip_pane_id="$(tmux display-message -p -t "$skip_pane_target" '#{pane_id}' 2>/dev/null)" \
    || { echo "auto-switch: failed to resolve skip pane $skip_pane_target" >&2; exit 1; }
fi

target=""
for candidate in $ranked; do
  resolved="$(tmux display-message -p -t "$candidate" '#{pane_id}' 2>/dev/null || true)"
  [[ -n "$resolved" ]] || continue
  [[ -n "$skip_pane_id" && "$resolved" == "$skip_pane_id" ]] && continue
  if is_usable_pane "$resolved"; then
    target="$resolved"
    break
  fi
done

if [[ -z "$target" ]]; then
  tmux display-message "auto-switch: no usable AI pane in ranked list"
  exit 1
fi

target_session="$(tmux display-message -p -t "$target" '#{session_name}')"
target_window_id="$(tmux display-message -p -t "$target" '#{window_id}')"
while IFS=$'\t' read -r client readonly control_mode; do
  [[ -n "$client" ]] || continue
  [[ "$readonly" == "1" || "$control_mode" == "1" ]] && continue
  if ! tmux switch-client -c "$client" -t "$target_session:" 2>/dev/null; then
    tmux switch-client -t "$target_session:"
  fi
done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}')

tmux select-window -t "$target_window_id"
tmux select-pane -t "$target"
