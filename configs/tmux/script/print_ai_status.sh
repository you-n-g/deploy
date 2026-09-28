#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

running=0
background=0
waiting=0
# Unread panes split by whether they are in the auto-switch list (the panes worth
# watching). The !N count is coloured by this split below.
waiting_in=0
waiting_out=0
ranked=" $(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true) "
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
    _ai_window_is_orchestrator "$window_name" && continue
  fi
  if [ "$pane_background" = "1" ]; then
    background=$((background + 1))
  elif [ "$pane_running" = "1" ]; then
    running=$((running + 1))
  elif [ "$pane_unread" = "1" ]; then
    waiting=$((waiting + 1))
    case "$ranked" in
      *" $pane_id "*) waiting_in=$((waiting_in + 1)) ;;
      *) waiting_out=$((waiting_out + 1)) ;;
    esac
  fi
done < <(tmux list-panes -a -F '#{session_name}|#{pane_id}|#{window_name}|#{@ai_agent_unread}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_pending}|#{@ai_agent_attribute}' 2>/dev/null)

# The !N unread count encodes where the unread panes are: all in the auto-switch
# list -> red (what I watch), all outside -> the group's cyan (least urgent),
# a mix -> orange in between. Reset to cyan after so nothing downstream inherits
# the override (the surrounding ai_group is cyan).
unread_part() {
  local color=""
  if [ "$waiting_out" -eq 0 ]; then
    color="colour196"          # all in the list
  elif [ "$waiting_in" -gt 0 ]; then
    color="colour214"          # mixed
  fi
  if [ -n "$color" ]; then
    printf '#[fg=%s]!%s#[fg=cyan]' "$color" "$waiting"
  else
    printf '!%s' "$waiting"    # all outside: keep the group colour
  fi
}

parts=()
[ "$running" -gt 0 ] && parts+=("$running")
[ "$background" -gt 0 ] && parts+=("~${background}")
[ "$waiting" -gt 0 ] && parts+=("$(unread_part)")
if [ "${#parts[@]}" -eq 0 ]; then
  label="0"
else
  label="${parts[*]}"
fi

printf '%s\n' "$label"
