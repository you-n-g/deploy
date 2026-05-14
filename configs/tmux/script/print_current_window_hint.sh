#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"
source "$SCRIPT_DIR/ai_label.sh"

current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
[ -n "$current_window" ] || exit 0

hint=""
if ai_pane="$(_find_ai_pane_in_window "$current_window" 2>/dev/null)" && [ -n "$ai_pane" ]; then
  hint="$(tmux show -pv -t "$ai_pane" @ai_agent_attribute 2>/dev/null || true)"
fi

[ -n "$hint" ] || exit 0
clean_hint="$(printf '%s' "$hint" | strip_tmux_format)"
[ -n "$clean_hint" ] || exit 0
ai_display_prefix "$clean_hint" 10
