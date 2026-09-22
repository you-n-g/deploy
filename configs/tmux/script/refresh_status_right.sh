#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Wait for TPM/theme plugins to finish populating status-right first.
sleep 1

# Gruvbox's colour237 inactive border blends into its background. Keep inactive
# pane edges visible in mid-grey and make the active pane unmistakably warm.
tmux set-option -g pane-border-style 'fg=colour244'
tmux set-option -g pane-active-border-style 'fg=colour214,bold'

mount_path="$(tmux show-options -gqv @disk-usage-path 2>/dev/null || true)"
if [ -z "$mount_path" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    mount_path="/System/Volumes/Data"
  else
    mount_path="/"
  fi
fi

display_path="$(printf '%s' "${mount_path}" | awk -F'/' '{
  if (NF <= 2) { print $0; next }
  r = ""
  for (i = 2; i < NF; i++) r = r "/" substr($i, 1, 1)
  print r "/" $NF
}')"

theme="$(tmux show-options -gqv @tmux-gruvbox 2>/dev/null || true)"
if [ -z "$theme" ]; then
  theme="dark"
fi

status_length="$(tmux show-options -gqv status-right-length 2>/dev/null || true)"
case "$status_length" in
  ''|*[!0-9]*)
    status_length=100
    ;;
esac

if [ "$status_length" -lt 158 ]; then
  tmux set-option -g status-right-length 158
fi

# The session segment mirrors tmux-gruvbox-{light,dark}.conf's status-left; the
# AI group is prepended to it below.
case "$theme" in
  light)
    status_right='#[bg=colour243,fg=colour237,nobold,noitalics,nounderscore]#[bg=colour237,fg=colour255] #h '
    session_segment='#[bg=colour243,fg=colour255] #S #[bg=colour252,fg=colour243,nobold,noitalics,nounderscore]'
    ;;
  *)
    status_right='#[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] #h '
    session_segment='#[bg=colour241,fg=colour248] #S #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]'
    ;;
esac

decorate_window_status() {
  option_name="$1"
  # The window name keeps this fg unless the pane is the next auto-switch target;
  # colour223 is the theme's normal name fg, colour239 the current-window one.
  name_fg="$2"
  option_value="$(tmux show-options -gqv "$option_name")"
  styled_index='#{?#{m/r:(^| )#{pane_id}( |$),#{@auto_switch_ranked_panes}},#[bold]#[underscore]#I#[nobold]#[nounderscore],#I}'
  has_ai_state='#{||:#{!=:#{@ai_agent_running},},#{||:#{!=:#{@ai_agent_background},},#{||:#{!=:#{@ai_agent_unread},},#{||:#{!=:#{@ai_agent_pending},},#{!=:#{@ai_agent_attribute},}}}}}'
  state_symbol="#{?#{!=:#{@ai_agent_pending},},⏸,#{?#{==:#{@ai_agent_background},1},◒,#{?#{==:#{@ai_agent_running},1},●,#{?#{==:#{@ai_agent_unread},1},◉,○}}}}"
  state_suffix="#{?${has_ai_state},${state_symbol},}"
  option_value="${option_value// #I / ${styled_index} ${state_suffix}}"
  # The next auto-switch target's name turns green; every other name keeps the
  # theme fg. @auto_switch_next_pane is refreshed by refresh-next-pane.sh.
  is_next='#{&&:#{!=:#{@auto_switch_next_pane},},#{==:#{pane_id},#{@auto_switch_next_pane}}}'
  styled_name="#{?${is_next},#[fg=green],}#W#{?${is_next},#[fg=${name_fg}],}"
  option_value="${option_value//#W/${styled_name}}"
  tmux set-option -g "$option_name" "$option_value"
}

decorate_window_status window-status-format colour223
decorate_window_status window-status-current-format colour239

status_right="${status_right}#[fg=green]#(${SCRIPT_DIR}/print_resource_status.sh)#[default]"
status_right="${status_right} #[fg=yellow]#(df -h ${mount_path} 2>/dev/null | awk 'NR==2 {print \"${display_path} \" \$5 \" \" \$4}')#[default]"
# General pane history belongs before the AI status group. Each client evaluates
# its own history position.
status_right="${status_right} #[norange]#[fg=colour214]#{E:@jump-history-status}#{E:@jump-history-waiting}#[default]"
tmux set-option -g status-right "$status_right"

# The AI group -- agent counts, auto-switch hint/mode symbol, and the current
# window's attribute/rank -- is what gets watched all day, so it sits at the far
# left, ahead of the session name, instead of at the tail of status-right.
ai_group="#[fg=cyan]🤖 #(${SCRIPT_DIR}/print_ai_status.sh)#[default]"
# Keep the current-window hint, target-state symbol, and mode symbol in one clickable
# range. Desktop tmux clients report this as sb_a; mobile clients may not
# report status ranges at all, so debug MouseDown1Status before changing this.
# The waiting-hint and window-hint scripts print their own leading space, so
# an empty one leaves no gap: "3 ↻" vs "3 ● ↻" (the mode symbol carries its
# own leading space too).
ai_group="${ai_group}#[range=user|sb_a]#[fg=colour201]#(${SCRIPT_DIR}/../auto-switch/print-waiting-hint.sh)#[fg=green]#{@auto_switch_status_symbol}#[fg=colour203]#(${SCRIPT_DIR}/print_current_window_hint.sh)#[norange default]"

# One cell in the plain status background between the AI group and the session
# block, so the block keeps the theme's own one-cell pad.
tmux set-option -g status-left "${ai_group} ${session_segment}"

status_left_length="$(tmux show-options -gqv status-left-length 2>/dev/null || true)"
case "$status_left_length" in
  ''|*[!0-9]*)
    status_left_length=0
    ;;
esac
if [ "$status_left_length" -lt 120 ]; then
  tmux set-option -g status-left-length 120
fi
