#!/usr/bin/env bash

set -eu

current_session="${1:?usage: close_current_session.sh CURRENT_SESSION [LAST_SESSION]}"
last_session="${2:-}"

if ! tmux has-session -t "${current_session}:" 2>/dev/null; then
  tmux display-message "Session not found: ${current_session}"
  exit 1
fi

target_session=""
if [ -n "$last_session" ] \
  && [ "$last_session" != "$current_session" ] \
  && tmux has-session -t "${last_session}:" 2>/dev/null; then
  target_session="$last_session"
fi

if [ -z "$target_session" ]; then
  target_session="$(
    tmux list-sessions -F '#S' \
      | awk -v current="$current_session" '$0 != current { print; exit }'
  )"
fi

if [ -z "$target_session" ]; then
  tmux display-message "No other session to switch to; keeping ${current_session}"
  exit 1
fi

tmux switch-client -t "${target_session}:"
tmux kill-session -t "${current_session}:"
