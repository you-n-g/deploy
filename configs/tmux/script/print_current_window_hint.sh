#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=ai_label.sh
source "$SCRIPT_DIR/ai_label.sh"

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
[ -n "$current_pane" ] || exit 0
current_window="$(tmux display-message -p -t "$current_pane" '#{window_id}' 2>/dev/null || true)"
[ -n "$current_window" ] || exit 0

hint=""
in_auto_switch=0
rank_label=""

ranked="$(tmux show-options -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
declare -A pane_exists pane_rank
total=0
while IFS=$'\037' read -r pane; do
  [ -n "$pane" ] || continue
  pane_exists["$pane"]=1
done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)
for candidate in $ranked; do
  [ -n "${pane_exists[$candidate]:-}" ] || continue
  total=$((total + 1))
  if [ -z "${pane_rank[$candidate]:-}" ]; then
    pane_rank["$candidate"]="$total"
  fi
done

ai_pane=""
fallback_pane=""
while IFS=$'\037' read -r pane active attribute running background unread pending; do
  [ -n "$pane" ] || continue
  has_ai_signal=0
  if [ -n "$attribute$running$background$unread$pending${pane_rank[$pane]:-}" ]; then
    has_ai_signal=1
  fi
  if [ "$active" = "1" ] && [ "$has_ai_signal" = "1" ]; then
    ai_pane="$pane"
    hint="$attribute"
    break
  fi
  if [ -z "$fallback_pane" ] && [ "$has_ai_signal" = "1" ]; then
    fallback_pane="$pane"
    fallback_hint="$attribute"
  fi
done < <(tmux list-panes -t "$current_window" -F $'#{pane_id}\037#{pane_active}\037#{@ai_agent_attribute}\037#{@ai_agent_running}\037#{@ai_agent_background}\037#{@ai_agent_unread}\037#{@ai_agent_pending}' 2>/dev/null)
if [ -z "$ai_pane" ] && [ -n "$fallback_pane" ]; then
  ai_pane="$fallback_pane"
  hint="${fallback_hint:-}"
fi

if [ -n "$ai_pane" ] && [ -n "${pane_rank[$ai_pane]:-}" ]; then
  in_auto_switch=1
  rank_label="${pane_rank[$ai_pane]}/${total}"
fi
pending="$(tmux show -pv -t "$current_pane" @ai_agent_pending 2>/dev/null || true)"

clean_hint="$(printf '%s' "$hint" | strip_tmux_format)"
if [ -n "$clean_hint" ] || [ -n "$rank_label" ]; then
  if [ "$in_auto_switch" = "1" ]; then
    printf '#[fg=colour124,bold]'
  fi
  if [ -n "$clean_hint" ]; then
    if [ "$in_auto_switch" = "1" ]; then
      printf '#[underscore]'
    fi
    ai_display_prefix "$clean_hint" 10
  fi
  if [ -n "$rank_label" ]; then
    if [ "$in_auto_switch" = "1" ]; then
      printf '#[nounderscore]'
    fi
    if [ -n "$clean_hint" ]; then
      printf ' '
    fi
    printf '%s' "$rank_label"
  fi
  if [ "$in_auto_switch" = "1" ]; then
    printf '#[nobold,nounderscore,fg=colour203]'
  fi
fi

if [ "$pending" = "1" ]; then
  printf '#[fg=colour201,bold] ⏸#[nobold,fg=colour203]'
fi
