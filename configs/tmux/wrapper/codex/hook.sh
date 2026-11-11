#!/usr/bin/env bash
set -euo pipefail
event="${1:?usage: hook.sh init|running|pretool|stop [PANE]}"
target="${2:-${TMUX_PANE:-}}"
[[ -n "$target" ]] || exit 0
tracker="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../script" && pwd)/track_ai_agent_state.sh"
case "$event" in
  init) AI_AGENT_STATE_SOURCE=codex-hook:session-start exec "$tracker" init "$target" ;;
  running)
    input="$(cat)"
    AI_AGENT_PROMPT="$(jq -r '.prompt // empty' <<<"$input")" \
    AI_AGENT_SESSION_ID="$(jq -r '.session_id // empty' <<<"$input")" \
    AI_AGENT_CWD="$(jq -r '.cwd // empty' <<<"$input")" \
    AI_AGENT_STATE_SOURCE=codex-hook:user-prompt-submit exec "$tracker" running "$target"
    ;;
  pretool)
    [[ "$(tmux show-option -pqv -t "$target" @ai_agent_running)" != 1 ]] || exit 0
    AI_AGENT_STATE_SOURCE=codex-hook:pre-tool-use exec "$tracker" running "$target"
    ;;
  stop) AI_AGENT_STATE_SOURCE=codex-hook:stop exec "$tracker" idle "$target" ;;
  *) echo "Unknown hook event: $event" >&2; exit 1 ;;
esac
