#!/usr/bin/env bash
set -euo pipefail

# Write @auto_switch_next_pane: the pane `prefix + a` (switch-next.sh) would jump
# to, i.e. the first pane in @auto_switch_ranked_panes that is usable right now
# (not running, not background, no pending) other than the one you are on. The
# window-status formats colour this pane's name green so the next target stands
# out from the rest of the ranked list, which only gets a bold/underscored index.
#
# switch-next.sh skips the caller's current pane (`--skip-pane #{pane_id}`), so if
# you are already on the top-priority pane the second one is the target. This
# global option can't be per-client, so it skips the active pane of every
# attached session; with one client that is exactly your current pane.
#
# Runs on every status refresh (state changes and window/session events all go
# through refresh_status_lines.sh), which is exactly when the target can change.

ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
if [[ -z "$ranked" ]]; then
  tmux set-option -guq @auto_switch_next_pane 2>/dev/null || true
  exit 0
fi

# The active pane of each attached session: the pane a viewer is sitting on, and
# thus the one prefix + a would skip.
skip=" "
while IFS= read -r pane; do
  [[ -n "$pane" ]] || continue
  skip+="$pane "
done < <(tmux list-panes -a -F '#{?#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}},#{pane_id},}' 2>/dev/null || true)

# One snapshot of the state that decides usability, keyed by pane id.
declare -A running background pending
while IFS='|' read -r pane r b p; do
  [[ -n "$pane" ]] || continue
  running[$pane]="$r"
  background[$pane]="$b"
  pending[$pane]="$p"
done < <(tmux list-panes -a -F '#{pane_id}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_pending}' 2>/dev/null || true)

next=""
for candidate in $ranked; do
  # A pane that dropped out of the layout keeps no state row; skip it.
  [[ -v running[$candidate] ]] || continue
  [[ "$skip" == *" $candidate "* ]] && continue
  if [[ "${running[$candidate]}" != "1" \
    && "${background[$candidate]}" != "1" \
    && -z "${pending[$candidate]}" ]]; then
    next="$candidate"
    break
  fi
done

if [[ -n "$next" ]]; then
  tmux set-option -gq @auto_switch_next_pane "$next"
else
  tmux set-option -guq @auto_switch_next_pane 2>/dev/null || true
fi
