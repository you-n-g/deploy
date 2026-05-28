#!/usr/bin/env bash

set -euo pipefail

event="${1:?usage: claude_agent_state_hook.sh init|running|stop [TARGET]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TRACK_STATE="$SCRIPT_DIR/track_ai_agent_state.sh"
target="${2:-${TMUX_PANE:?usage: claude_agent_state_hook.sh init|running|stop [TARGET]}}"

has_background_work() {
  local result

  if ! result="$(jq -r '
    def nonempty:
      if type == "array" then length > 0
      elif type == "object" then length > 0
      elif type == "string" then length > 0
      elif type == "boolean" then .
      elif type == "number" then . != 0
      else false
      end;
    ((.background_tasks // null) | nonempty)
    or ((.session_crons // null) | nonempty)
  ')"; then
    echo "failed to parse Claude hook input JSON" >&2
    exit 1
  fi

  [ "$result" = "true" ]
}

case "$event" in
  init)
    exec "$TRACK_STATE" init "$target"
    ;;
  running)
    exec "$TRACK_STATE" running "$target"
    ;;
  stop)
    if has_background_work; then
      exec "$TRACK_STATE" background "$target"
    fi
    exec "$TRACK_STATE" idle "$target"
    ;;
  *)
    echo "unknown Claude agent state hook event: $event" >&2
    exit 2
    ;;
esac
