#!/usr/bin/env bash
# Go to the shell window of the code session, making it first if there is none
# (in WORKDIR, the pane the key was pressed in). prefix k s.
#
# The window is found by its @code_shell tag, not by name: a shell renames its
# window after whatever runs in it, and a window the user named "shell" for
# something else must not be taken over.
#
# usage: ensure_code_shell.sh WORKDIR
set -euo pipefail

session="code"
workdir="${1:?usage: ensure_code_shell.sh WORKDIR}"

tmux has-session -t "=$session" 2>/dev/null || { tmux display-message "code shell: no session named $session"; exit 1; }

window_id="$(tmux list-windows -t "=$session" -F '#{window_id} #{@code_shell}' | awk '$2 == "1" { print $1; exit }')"
if [[ -z "$window_id" ]]; then
  window_id="$(tmux new-window -d -P -F '#{window_id}' -t "=$session:" -n shell -c "$workdir")"
  tmux set-window-option -t "$window_id" @code_shell 1
  tmux set-window-option -t "$window_id" automatic-rename off
fi
tmux switch-client -t "=$session"
tmux select-window -t "$window_id"
