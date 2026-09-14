#!/bin/bash
# Switch to or create the orchestrator using the current local configuration.
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../shell/env.sh"

args=(--window-name orchestrator)
if [[ -n "${TMUX_ORCHESTRATOR_TOOL:-}" ]]; then
    args+=(--tool "$TMUX_ORCHESTRATOR_TOOL")
fi
if [[ -n "${TMUX_ORCHESTRATOR_MODEL:-}" ]]; then
    args+=(--model "$TMUX_ORCHESTRATOR_MODEL")
fi
if [[ -n "${TMUX_ORCHESTRATOR_REASONING_EFFORT:-}" ]]; then
    args+=(--reasoning-effort "$TMUX_ORCHESTRATOR_REASONING_EFFORT")
fi

exec "$SCRIPT_DIR/tmuxg.sh" "${args[@]}" "$@"
