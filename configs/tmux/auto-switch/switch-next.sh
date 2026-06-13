#!/usr/bin/env bash
set -euo pipefail

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

skip_pane_id=""
if [[ -n "$skip_pane_target" ]]; then
  skip_pane_id="$(tmux display-message -p -t "$skip_pane_target" '#{pane_id}' 2>/dev/null)" \
    || { echo "auto-switch: failed to resolve skip pane $skip_pane_target" >&2; exit 1; }
fi

pane_rows="$(tmux list-panes -a -F $'#{pane_id}\037#{@ai_agent_running}\037#{@ai_agent_background}\037#{@ai_agent_pending}\037#{session_name}\037#{window_id}' 2>/dev/null || true)"

lookup_pane_row() {
  local wanted="$1" pane running background pending session window_id

  while IFS=$'\037' read -r pane running background pending session window_id; do
    [[ "$pane" == "$wanted" ]] || continue
    printf '%s\037%s\037%s\037%s\037%s\n' "$running" "$background" "$pending" "$session" "$window_id"
    return 0
  done <<< "$pane_rows"

  return 1
}

target=""
target_session=""
target_window_id=""
for candidate in $ranked; do
  [[ -n "$skip_pane_id" && "$candidate" == "$skip_pane_id" ]] && continue
  row="$(lookup_pane_row "$candidate" || true)"
  [[ -n "$row" ]] || continue
  IFS=$'\037' read -r running background pending session window_id <<< "$row"
  if [[ "$running" != "1" \
    && "$background" != "1" \
    && "$pending" != "1" ]]; then
    target="$candidate"
    target_session="$session"
    target_window_id="$window_id"
    break
  fi
done

if [[ -z "$target" ]]; then
  tmux display-message "auto-switch: no usable AI pane in ranked list"
  exit 0
fi

while IFS=$'\t' read -r client readonly control_mode; do
  [[ -n "$client" ]] || continue
  [[ "$readonly" == "1" || "$control_mode" == "1" ]] && continue
  if ! tmux switch-client -c "$client" -t "$target_session:" 2>/dev/null; then
    tmux switch-client -t "$target_session:"
  fi
done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}')

tmux select-window -t "$target_window_id"
tmux select-pane -t "$target"
