#!/bin/bash

# Print the globally most recently visited AI pane, excluding one pane.
#
# Usage: last_ai_pane.sh [--exclude PANE]
#   --exclude PANE   pane to leave out, any tmux pane target
#                    (default: the calling client's current pane)
#
# Prints one "session:window.pane" line. Exits 1 when there is no other AI pane.
#
# "Most recently visited" comes from @last_visit, stamped by update_last_visit.sh
# on every pane switch. tmux's own {last} cannot answer this: as a pane target it
# means the previous pane *within the current window*, so a caller that happens to
# sit next to a split gets that neighbour instead of the pane the user actually
# came from. Only the timestamps see across windows and sessions.
#
# The exclusion is by pane id rather than by "session:window.pane" because the
# latter shifts whenever windows are renumbered.
#
# Only panes that carry @last_visit count. _ai_pane_rows sorts an unvisited
# pane by its window_activity instead, and a Claude TUI redraws often enough to
# keep that a few seconds old -- so every pane not yet visited since a restore
# would outrank the pane the user really came from a minute ago.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

exclude=""
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --exclude) exclude="$2"; shift 2 ;;
        *) shift ;;
    esac
done

exclude_id="$(tmux display-message -p -t "${exclude:-}" '#{pane_id}' 2>/dev/null || true)"

# $2 is "session:index.pane" and $4 is the pane id; see _ai_pane_rows for the
# full column list. Rows arrive sorted by last_visit desc, so the first row that
# is not the excluded pane is the answer.
visited="$(tmux list-panes -a -F '#{pane_id} #{@last_visit}' | awk 'NF == 2 { print $1 }')"
row="$(_ai_pane_rows -a | awk -F $'\t' -v skip="$exclude_id" '
    FNR == NR { visited[$1] = 1; next }
    $4 != skip && ($4 in visited) && !found { print; found = 1 }
' <(printf '%s\n' "$visited") -)"
[[ -n "$row" ]] || exit 1

printf '%s\n' "$(printf '%s' "$row" | cut -f2)"
