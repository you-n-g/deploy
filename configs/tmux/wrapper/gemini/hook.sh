#!/usr/bin/env bash
# Gemini hook JSON -> the shared TMA state machine. stdout is JSON only.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="${TMUX_PANE:-}"
if [ -z "$target" ]; then
  [ -z "${TMUX:-}" ] || { echo "inside tmux but TMUX_PANE is unset" >&2; exit 1; }
  printf '{}\n'
  exit 0
fi

input="$(cat)"
event="$(jq -er '.hook_event_name' <<<"$input")"
export AI_AGENT_STATE_SOURCE="gemini-hook:$event"
# Only BeforeAgent supplies a new user prompt to the prompt log.
unset AI_AGENT_PROMPT
case "$event" in
  SessionStart|SessionEnd) state=init ;;
  BeforeAgent)
    state=running
    AI_AGENT_PROMPT="$(jq -er '.prompt' <<<"$input")"
    AI_AGENT_SESSION_ID="$(jq -er '.session_id' <<<"$input")"
    AI_AGENT_CWD="$(jq -er '.cwd' <<<"$input")"
    export AI_AGENT_PROMPT AI_AGENT_SESSION_ID AI_AGENT_CWD
    ;;
  BeforeModel|BeforeTool|PreCompress)
    if [ "$(tmux show-option -pqv -t "$target" @ai_agent_running)" = 1 ]; then
      printf '{}\n'
      exit 0
    fi
    state=running
    ;;
  AfterAgent) state=idle ;;
  Notification)
    if [ "$(jq -er '.notification_type' <<<"$input")" != ToolPermission ]; then
      printf '{}\n'
      exit 0
    fi
    state=idle
    ;;
  *) echo "unknown Gemini hook event: $event" >&2; exit 1 ;;
esac

"$SCRIPT_DIR/../../script/track_ai_agent_state.sh" "$state" "$target" >&2
printf '{}\n'
