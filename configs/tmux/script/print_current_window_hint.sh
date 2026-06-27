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
total=0
ranked_panes=""
ranked_ranks=""
for candidate in $ranked; do
  tmux display-message -p -t "$candidate" '#{pane_id}' >/dev/null 2>&1 || continue
  total=$((total + 1))
  case " $ranked_panes " in
    *" $candidate "*) ;;
    *)
      ranked_panes="${ranked_panes:+$ranked_panes }$candidate"
      ranked_ranks="${ranked_ranks:+$ranked_ranks }$total"
      ;;
  esac
done

pane_rank() {
  local wanted="$1" pane rank
  set -- $ranked_panes
  for rank in $ranked_ranks; do
    pane="${1:-}"
    shift || true
    [ "$pane" = "$wanted" ] || continue
    printf '%s\n' "$rank"
    return 0
  done
  return 1
}

ai_pane=""
fallback_pane=""
while IFS='|' read -r pane active attribute running background unread pending; do
  [ -n "$pane" ] || continue
  current_rank="$(pane_rank "$pane" 2>/dev/null || true)"
  has_ai_signal=0
  if [ -n "$attribute$running$background$unread$pending$current_rank" ]; then
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
done < <(tmux list-panes -t "$current_window" -F '#{pane_id}|#{pane_active}|#{@ai_agent_attribute}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_unread}|#{@ai_agent_pending}' 2>/dev/null)
if [ -z "$ai_pane" ] && [ -n "$fallback_pane" ]; then
  ai_pane="$fallback_pane"
  hint="${fallback_hint:-}"
fi

ai_pane_rank="$(pane_rank "$ai_pane" 2>/dev/null || true)"
if [ -n "$ai_pane" ] && [ -n "$ai_pane_rank" ]; then
  in_auto_switch=1
  rank_label="${ai_pane_rank}/${total}"
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

if [ -n "$pending" ]; then
  printf '#[fg=colour201,bold] ⏸#[nobold,fg=colour203]'
fi
