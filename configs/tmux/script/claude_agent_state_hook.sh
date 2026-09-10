#!/usr/bin/env bash

set -euo pipefail

event="${1:?usage: claude_agent_state_hook.sh init|running|pretool|stop [TARGET]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TRACK_STATE="$SCRIPT_DIR/track_ai_agent_state.sh"

hook_input=""
# Claude hands the hook its event JSON on stdin, and stdin drains once. Read it
# lazily and keep it: the pretool fast path below has to stay at a single tmux
# read, so nothing should touch stdin unless it needs a field out of it.
read_hook_input() {
  [ -n "$hook_input" ] || hook_input="$(cat)"
}

# The pane, if any, that has parked itself on this background session.
#
# <config>/sessions/<pid>.json describes a pane's own session; a pane that
# parked onto a job also records that job's short id there, and the short id is
# the first segment of the job's session id. So the pane showing us is the one
# pointing back at us.
_parked_pane_for_session() {
  local session_id="$1"
  local short="${session_id%%-*}"
  local state_file line tmux_target

  [ -n "$short" ] || return 1
  state_file="$(grep -l "\"parkedJobId\":\"$short\"" \
    "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/sessions/*.json 2>/dev/null | head -1 || true)"
  [ -n "$state_file" ] || return 1

  # These files carry no trailing newline, so read reports EOF on a good line.
  line=""
  IFS= read -r line <"$state_file" || true
  case "$line" in
    *'"tmux":"'*) ;;
    *) return 1 ;;
  esac

  tmux_target="${line#*'"tmux":"'}"
  tmux_target="${tmux_target%%'"'*}"
  # "session:@window.%pane" -> "%pane"
  printf '%s\n' "${tmux_target##*.}"
}

# Tags the log rows this hook produces; a parked background session reports
# against somebody else's pane, which is worth telling apart in the log.
source_kind="claude-hook"
target="${2:-${TMUX_PANE:-}}"
if [ -z "$target" ]; then
  # Missing TMUX_PANE *inside* tmux is a broken pane environment, not a
  # background session.
  [ -z "${TMUX:-}" ] || { echo "inside tmux but TMUX_PANE is unset" >&2; exit 1; }

  # No pane of our own. Claude Code deletes TMUX and TMUX_PANE from background
  # sessions on purpose -- they are on the deny-list it applies to a `--bg`
  # session or a warm spare -- and such a session must not touch the state of
  # the pane that happened to launch it: that pane runs its own hooks.
  #
  # Parking is the exception. A pane can park itself onto a job and sit there
  # showing it, and then the pane's own session is idle with nothing to report
  # while the turn on screen is ours. Only the pane pointing at us is claimed,
  # so a background session nobody is watching still reports nothing.
  read_hook_input
  session_id="$(printf '%s' "$hook_input" | jq -r '.session_id // empty')"
  target="$(_parked_pane_for_session "$session_id")" || exit 0
  source_kind="claude-job"
fi

has_background_work() {
  local result

  read_hook_input
  if ! result="$(printf '%s' "$hook_input" | jq -r '
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
    AI_AGENT_STATE_SOURCE="$source_kind:init" exec "$TRACK_STATE" init "$target"
    ;;
  running)
    # UserPromptSubmit is the one event that carries the submitted text, so it
    # is where the prompt log gets its rows. Read it here rather than letting
    # the tracker read stdin: the tracker has a dozen callers that hand it no
    # JSON at all, and a blocking read on this path would stall the pane.
    read_hook_input
    AI_AGENT_PROMPT="$(printf '%s' "$hook_input" | jq -r '.prompt // empty')" \
      AI_AGENT_STATE_SOURCE="$source_kind:running" exec "$TRACK_STATE" running "$target"
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
    AI_AGENT_STATE_SOURCE="$source_kind:pretool-running" exec "$TRACK_STATE" running "$target"
    ;;
  stop)
    if has_background_work; then
      AI_AGENT_STATE_SOURCE="$source_kind:stop-background" exec "$TRACK_STATE" background "$target"
    fi
    AI_AGENT_STATE_SOURCE="$source_kind:stop-idle" exec "$TRACK_STATE" idle "$target"
    ;;
  *)
    echo "unknown Claude agent state hook event: $event" >&2
    exit 2
    ;;
esac
