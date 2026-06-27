#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

running=0
background=0
waiting=0
blacklist_regexes="$(_tmuxg_session_blacklist_regexes)"
show_orchestrator=0
if _tmuxg_show_orchestrator_enabled; then
  show_orchestrator=1
fi
while IFS='|' read -r session_name pane_id window_name pane_unread pane_running pane_background _pane_pending _attribute; do
  [ -n "$session_name" ] || continue
  _tmuxg_session_is_blacklisted "$session_name" "$blacklist_regexes" && continue
  [ -n "$pane_id" ] || continue
  [ -n "${pane_unread}${pane_running}${pane_background}${_pane_pending}${_attribute}" ] || continue
  if [ "$show_orchestrator" = "0" ]; then
    display_window_name="$window_name"
    _strip_ai_window_state_prefix "$window_name" display_window_name
    [ "$display_window_name" = "orchestrator" ] && continue
  fi
  if [ "$pane_background" = "1" ]; then
    background=$((background + 1))
  elif [ "$pane_running" = "1" ]; then
    running=$((running + 1))
  elif [ "$pane_unread" = "1" ]; then
    waiting=$((waiting + 1))
  fi
done < <(tmux list-panes -a -F '#{session_name}|#{pane_id}|#{window_name}|#{@ai_agent_unread}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_pending}|#{@ai_agent_attribute}' 2>/dev/null)

parts=()
[ "$running" -gt 0 ] && parts+=("$running")
[ "$background" -gt 0 ] && parts+=("~${background}")
[ "$waiting" -gt 0 ] && parts+=("!${waiting}")
if [ "${#parts[@]}" -eq 0 ]; then
  label="0"
else
  label="${parts[*]}"
fi

printf '%s\n' "$label"
