#!/usr/bin/env bash

set -eu

# Wait for TPM/theme plugins to finish populating status-right first.
sleep 1

mount_path="$(tmux show-options -gqv @disk-usage-path 2>/dev/null || true)"
if [ -z "$mount_path" ]; then
  mount_path="/"
fi

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

if [ "$status_length" -lt 140 ]; then
  tmux set-option -g status-right-length 140
fi

case "$theme" in
  light)
    status_right='#[bg=colour243,fg=colour237,nobold,noitalics,nounderscore]#[bg=colour237,fg=colour255] #h '
    ;;
  *)
    status_right='#[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] #h '
    ;;
esac

status_right="${status_right}#[fg=green]#(\$TMUX_PLUGIN_MANAGER_PATH/tmux-mem-cpu-load/tmux-mem-cpu-load --colors --powerline-right -g 0 -t 1 --interval 2)#[default]"
status_right="${status_right} #[fg=yellow]#(df -h ${mount_path} 2>/dev/null | awk 'NR==2 {print \"${mount_path} \" \$(NF-1) \" \" \$4}')#[default]"

tmux set-option -g status-right "$status_right"
