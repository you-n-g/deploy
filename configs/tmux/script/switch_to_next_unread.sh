#!/usr/bin/env bash
# Switch directly to the next unread AI pane across all sessions (prefix + k u).
#
# Eligibility matches print_ai_status.sh / pane_list.awk: @ai_agent_unread=1,
# excluding the current pane, blacklisted sessions, hidden orchestrator windows,
# and states that outrank unread (pending, running, done; background+unread is
# kept). Priority:
#   1. User windows (@tma_created != 1) in @auto_switch_ranked_panes, in rank order
#   2. Other user windows, most recently visited (@last_visit / window_activity) first
#   3. TMA-created windows (@tma_created = 1), same order
#
# usage: switch_to_next_unread.sh [--client CLIENT] [CURRENT_PANE]
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

usage="usage: switch_to_next_unread.sh [--client CLIENT] [CURRENT_PANE]"
client=""
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --client)
      [[ $# -ge 2 ]] || { echo "$usage" >&2; exit 2; }
      client="$2"
      shift 2
      ;;
    -h|--help)
      echo "$usage"
      exit 0
      ;;
    *)
      echo "$usage" >&2
      exit 2
      ;;
  esac
done

current_pane="${1:-${TMUX_PANE:-}}"
current_id=""
if [[ -n "$current_pane" ]]; then
  current_id="$(tmux display-message -p -t "$current_pane" '#{pane_id}' 2>/dev/null || true)"
fi

blacklist_regexes="$(_tmuxg_session_blacklist_regexes)"
show_orchestrator=0
if _tmuxg_show_orchestrator_enabled; then
  show_orchestrator=1
fi

declare -A rank_of=()
rank_idx=0
for candidate in $(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true); do
  [[ "$candidate" == %* ]] || continue
  [[ -n "${rank_of[$candidate]:-}" ]] && continue
  rank_idx=$((rank_idx + 1))
  rank_of["$candidate"]="$rank_idx"
done

candidates=""
# Every field before window_name is guaranteed non-empty so bash's whitespace IFS
# tab splitting never collapses adjacent tabs.
while IFS=$'\t' read -r pane_id is_unread is_running is_pending is_done tma_created last_visit window_activity session_name window_name; do
  [[ -n "$pane_id" ]] || continue
  [[ "$pane_id" == "$current_id" ]] && continue
  [[ "$is_unread" == "1" ]] || continue
  _tmuxg_session_is_blacklisted "$session_name" "$blacklist_regexes" && continue
  if [[ "$show_orchestrator" == "0" ]] && _ai_window_is_orchestrator "$window_name"; then
    continue
  fi
  [[ "$is_pending" != "1" ]] || continue
  [[ "$is_running" != "1" ]] || continue
  [[ "$is_done" != "1" ]] || continue

  visit_ts="$last_visit"
  (( visit_ts > 0 )) || visit_ts="$window_activity"

  seq_pos="${rank_of[$pane_id]:-0}"
  if [[ "$tma_created" == "1" ]]; then
    if (( seq_pos > 0 )); then
      tier=2
      ord="$seq_pos"
    else
      tier=3
      ord=0
    fi
  else
    if (( seq_pos > 0 )); then
      tier=0
      ord="$seq_pos"
    else
      tier=1
      ord=0
    fi
  fi

  printf -v line '%d\t%08d\t%d\t%d\t%s' "$tier" "$ord" "$visit_ts" "$window_activity" "$pane_id"
  candidates="${candidates:+$candidates$'\n'}$line"
done < <(tmux list-panes -a -F $'#{pane_id}\t#{==:#{@ai_agent_unread},1}\t#{==:#{@ai_agent_running},1}\t#{!=:#{@ai_agent_pending},}\t#{==:#{@ai_agent_done},1}\t#{==:#{@tma_created},1}\t#{?@last_visit,#{@last_visit},0}\t#{?window_activity,#{window_activity},0}\t#{session_name}\t#{window_name}' 2>/dev/null)

if [[ -z "$candidates" ]]; then
  tmux display-message "没有未读的 AI 窗口"
  exit 0
fi

target="$(printf '%s\n' "$candidates" | sort -t $'\t' -k1,1n -k2,2n -k3,3nr -k4,4nr | head -n 1 | cut -f5)"

if [[ -n "$client" ]]; then
  tmux switch-client -c "$client" -t "$target"
else
  tmux switch-client -t "$target" 2>/dev/null || true
  tmux select-window -t "$target"
  tmux select-pane -t "$target"
fi
"$SCRIPT_DIR/refresh_terminal_title.sh" >/dev/null 2>&1 || true
