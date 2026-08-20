#!/usr/bin/env bash

set -euo pipefail

event="${1:?usage: claude_agent_state_hook.sh init|running|pretool|stop [TARGET]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TRACK_STATE="$SCRIPT_DIR/track_ai_agent_state.sh"
target="${2:-${TMUX_PANE:?usage: claude_agent_state_hook.sh init|running|pretool|stop [TARGET]}}"

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
    AI_AGENT_STATE_SOURCE="claude-hook:init" exec "$TRACK_STATE" init "$target"
    ;;
  running)
    AI_AGENT_STATE_SOURCE="claude-hook:running" exec "$TRACK_STATE" running "$target"
    ;;
  pretool)
    # UserPromptSubmit is not the only way a foreground turn starts. A Stop hook
    # can block the stop and continue the same turn (goal mode does this), a
    # queued message can be consumed by the running turn, and auto-compaction
    # resumes mid-turn. None of those fire a hook that marks the pane running,
    # so the marker stays idle while the agent keeps working. Every one of those
    # continuations reaches a tool call, so PreToolUse is the event that closes
    # the gap.
    #
    # This fires on every tool call, so the already-running case must stay cheap:
    # one tmux read and no state write, rename, or status-line refresh.
    if [ "$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null || true)" = "1" ]; then
      exit 0
    fi
    AI_AGENT_STATE_SOURCE="claude-hook:pretool-running" exec "$TRACK_STATE" running "$target"
    ;;
  stop)
    if has_background_work; then
      AI_AGENT_STATE_SOURCE="claude-hook:stop-background" exec "$TRACK_STATE" background "$target"
    fi
    AI_AGENT_STATE_SOURCE="claude-hook:stop-idle" exec "$TRACK_STATE" idle "$target"
    ;;
  *)
    echo "unknown Claude agent state hook event: $event" >&2
    exit 2
    ;;
esac
