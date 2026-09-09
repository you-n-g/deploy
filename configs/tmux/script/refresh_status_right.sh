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

case "$theme" in
  light)
    status_right='#[bg=colour243,fg=colour237,nobold,noitalics,nounderscore]#[bg=colour237,fg=colour255] #h '
    ;;
  *)
    status_right='#[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] #h '
    ;;
esac

decorate_window_status() {
  option_name="$1"
  option_value="$(tmux show-options -gqv "$option_name")"
  styled_index='#{?#{m/r:(^| )#{pane_id}( |$),#{@auto_switch_ranked_panes}},#[bold]#[underscore]#I#[nobold]#[nounderscore],#I}'
  has_ai_state='#{||:#{!=:#{@ai_agent_running},},#{||:#{!=:#{@ai_agent_background},},#{||:#{!=:#{@ai_agent_unread},},#{||:#{!=:#{@ai_agent_pending},},#{!=:#{@ai_agent_attribute},}}}}}'
  state_symbol="#{?#{!=:#{@ai_agent_pending},},⏸,#{?#{==:#{@ai_agent_background},1},◒,#{?#{==:#{@ai_agent_running},1},●,#{?#{==:#{@ai_agent_unread},1},◉,○}}}}"
  state_suffix="#{?${has_ai_state},${state_symbol},}"
  option_value="${option_value// #I / ${styled_index} ${state_suffix}}"
  tmux set-option -g "$option_name" "$option_value"
}

decorate_window_status window-status-format
decorate_window_status window-status-current-format

status_right="${status_right}#[fg=green]#(${SCRIPT_DIR}/print_resource_status.sh)#[default]"
status_right="${status_right} #[fg=yellow]#(df -h ${mount_path} 2>/dev/null | awk 'NR==2 {print \"${display_path} \" \$5 \" \" \$4}')#[default]"
status_right="${status_right} #[fg=cyan]🤖 #(${SCRIPT_DIR}/print_ai_status.sh)#[default]"
# Keep the current-window hint, target-state symbol, and mode symbol in one clickable
# range. Desktop tmux clients report this as sb_a/right; mobile clients may not
# report status ranges at all, so debug MouseDown1Status before changing this.
status_right="${status_right} #[range=user|sb_a]#[fg=colour203]#(${SCRIPT_DIR}/print_current_window_hint.sh)#[fg=colour201]#(${SCRIPT_DIR}/../auto-switch/print-waiting-hint.sh)#[fg=green]#{@auto_switch_status_symbol} #[norange default]"

tmux set-option -g status-right "$status_right"
