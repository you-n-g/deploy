#!/bin/bash

# Print the AI pane nearest to PANE: one in PANE's own window first (a split
# or floating pane beside it), otherwise the one in the session window whose
# index is closest to PANE's. Ties go to the more recently visited pane.
#
# Usage: nearest_ai_pane.sh PANE
#
# Prints one "session:window.pane" line. Exits 1 when the session has no other
# AI pane. Behind nvim's \c<what>n.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

read -r self session index < <(tmux display-message -p -t "${1:?usage: nearest_ai_pane.sh PANE}" '#{pane_id} #{session_name} #{window_index}')

# _ai_pane_rows arrives sorted by last_visit desc; $2 is "session:index.pane",
# $4 the pane id. A stable sort by distance keeps that order within a tie.
row="$(_ai_pane_rows -s -t "$session:" | awk -F $'\t' -v skip="$self" -v here="$index" '
    $4 != skip {
        split($2, parts, /[:.]/)
        d = parts[2] - here
        print (d < 0 ? -d : d) "\t" NR "\t" $2
    }' | sort -t $'\t' -k1,1n -k2,2n | head -1)"
[[ -n "$row" ]] || exit 1

printf '%s\n' "$(printf '%s' "$row" | cut -f3)"
