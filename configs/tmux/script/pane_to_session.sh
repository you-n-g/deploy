#!/usr/bin/env bash
# Move PANE into another session as a new window after its highest-numbered
# one, and follow it there. WHERE picks the session:
#   last  the client's previous session (tmux's own, as prefix + L)  prefix + j n
#   pick  an fzf list of the other sessions, run in a floating pane  prefix + j N
#
# usage: pane_to_session.sh CLIENT PANE last|pick
set -euo pipefail

usage="usage: pane_to_session.sh CLIENT PANE last|pick"
client="${1:?$usage}"
pane="$(tmux display-message -p -t "${2:?$usage}" '#{pane_id}')"
here="$(tmux display-message -p -t "$pane" '#{session_name}')"

case "${3:?$usage}" in
  last)
    target="$(tmux display-message -p -c "$client" '#{client_last_session}')"
    [[ -n "$target" ]] || { tmux display-message "没有上一个 session"; exit 1; }
    ;;
  pick)
    # Most recently used first, the current session left out; the window
    # count and names help tell sessions apart.
    target="$(tmux list-sessions -F '#{session_last_attached} #{session_name}	#{session_windows} windows' \
      | sort -rn | cut -d' ' -f2- | awk -F '\t' -v here="$here" '$1 != here' \
      | fzf --delimiter '\t' --prompt "移到哪个 session > " --header "当前 pane 将成为所选 session 的最后一个窗口" \
      | cut -f1)" || exit 0  # fzf cancelled
    ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
[[ "$target" != "$here" ]] || { tmux display-message "目标就是当前 session"; exit 1; }

# Switch first: when PANE is the last one of its session, moving it destroys
# that session, which would detach a client still showing it.
tmux switch-client -c "$client" -t "$target"
# -a after {end}: a new window behind the highest-numbered one.
new="$(tmux break-pane -a -P -F '#{pane_id}' -s "$pane" -t "$target:{end}")"
tmux switch-client -c "$client" -t "$new"
