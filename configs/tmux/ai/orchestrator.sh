#!/bin/bash
# Switch to or create the orchestrator using the current local configuration.
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../shell/env.sh"

# The orchestrator follows the normal AI tool/model like any other window:
# tmuxg.sh defaults --tool to TMUX_AI_TOOL and the model to the tool's usual
# default. Only reasoning effort is pinned low -- it coordinates rather than
# doing deep work -- and tmuxg maps that to each tool (claude --effort,
# codex model_reasoning_effort). Override per invocation by passing another
# --reasoning-effort in "$@".
exec "$SCRIPT_DIR/tmuxg.sh" --window-name orchestrator --reasoning-effort low "$@"
