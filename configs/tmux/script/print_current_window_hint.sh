#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../ai/lib.sh
source "$SCRIPT_DIR/../ai/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=ai_label.sh
source "$SCRIPT_DIR/ai_label.sh"

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
[ -n "$current_pane" ] || exit 0
current_window="$(tmux display-message -p -t "$current_pane" '#{window_id}' 2>/dev/null || true)"
[ -n "$current_window" ] || exit 0

hint=""
in_auto_switch=0
if ai_pane="$(_find_ai_pane_in_window "$current_window" 2>/dev/null)" && [ -n "$ai_pane" ]; then
  hint="$(tmux show -pv -t "$ai_pane" @ai_agent_attribute 2>/dev/null || true)"
  ranked="$(tmux show-options -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
  case " $ranked " in
    *" $ai_pane "*) in_auto_switch=1 ;;
  esac
fi
pending="$(tmux show -pv -t "$current_pane" @ai_agent_pending 2>/dev/null || true)"

if [ -n "$hint" ]; then
  clean_hint="$(printf '%s' "$hint" | strip_tmux_format)"
  if [ -n "$clean_hint" ]; then
    if [ "$in_auto_switch" = "1" ]; then
      printf '#[fg=colour124,bold,underscore]'
    fi
    ai_display_prefix "$clean_hint" 10
    if [ "$in_auto_switch" = "1" ]; then
      printf '#[nobold,nounderscore,fg=colour203]'
    fi
  fi
fi

if [ "$pending" = "1" ]; then
  printf '#[fg=colour201,bold] ⏸#[nobold,fg=colour203]'
fi
