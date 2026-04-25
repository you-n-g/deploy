#!/bin/bash
# update_last_visit.sh — stamp @last_visit on the window being LEFT and the one being ENTERED.
#
# Usage:
#   update_last_visit.sh window  <session> <new_window>
#   update_last_visit.sh session <session> <new_window> <client>
#   update_last_visit.sh detach  <session> <window>     <client>
#
# State files track the last-known session:window per session / per client so
# we can back-stamp the window the user just left.

EVENT="$1"
SESSION="$2"
WINDOW="$3"
CLIENT="${4:-}"

NOW=$(date +%s)
STATE_DIR="${TMPDIR:-/tmp}/tmux-lastvisit"
mkdir -p "$STATE_DIR"

_safe() { echo "$1" | tr -cs 'a-zA-Z0-9_-' '_'; }

stamp() {
    tmux set -w -t "$1:$2" @last_visit "$NOW" 2>/dev/null || true
}

case "$EVENT" in
    window)
        # session-window-changed: #{session_name} and #{window_index} are the NEW window.
        # Read the previous window for this session, stamp it, then update state.
        state="$STATE_DIR/session_$(_safe "$SESSION")"
        if [ -f "$state" ]; then
            prev=$(cat "$state")
            [ "$prev" != "$WINDOW" ] && stamp "$SESSION" "$prev"
        fi
        stamp "$SESSION" "$WINDOW"
        echo "$WINDOW" > "$state"
        ;;

    session)
        # client-session-changed: #{session_name}:#{window_index} are the NEW session/window.
        # Read the previous session:window for this client, stamp it, then update state.
        cstate="$STATE_DIR/client_$(_safe "$CLIENT")"
        if [ -f "$cstate" ]; then
            prev=$(cat "$cstate")
            stamp "${prev%%:*}" "${prev##*:}"
        fi
        stamp "$SESSION" "$WINDOW"
        echo "$SESSION:$WINDOW" > "$cstate"
        # Also sync the per-session window state so the two trackers stay consistent.
        echo "$WINDOW" > "$STATE_DIR/session_$(_safe "$SESSION")"
        ;;

    detach)
        stamp "$SESSION" "$WINDOW"
        rm -f "$STATE_DIR/client_$(_safe "$CLIENT")"
        ;;
esac
