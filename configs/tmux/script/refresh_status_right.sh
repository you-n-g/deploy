#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Wait for TPM/theme plugins to finish populating status-right first.
sleep 1

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
status_right="${status_right} #[fg=yellow]#(df -h ${mount_path} 2>/dev/null | awk 'NR==2 {print \"${display_path} \" \$5 \" \" \$4}')#[default]"
status_right="${status_right} #[fg=cyan]🤖 #(${SCRIPT_DIR}/refresh_ai_status.sh)#[default]"

tmux set-option -g status-right "$status_right"
"$SCRIPT_DIR/refresh_ai_status.sh" --refresh >/dev/null
