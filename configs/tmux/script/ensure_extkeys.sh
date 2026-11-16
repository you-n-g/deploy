#!/usr/bin/env bash
# Re-assert modifyOtherKeys + Kitty disambiguation mode (\033[>4;2m\033[=1u)
# on attached xterm-256color clients.
#
# tmux sends Eneks only once when a client initially attaches. VS Code's
# persistent ptyHost keeps `tmux attach` alive across window reloads / SSH
# reconnects and replays terminal state via @xterm/addon-serialize, which
# restores DECSET 1004 focus reporting (\033[?1004h) but drops Kitty keyboard
# flags (\033[=1u), reverting Ctrl-[ to plain Escape until Eneks is sent again.
# `tmux source-file` on an already-attached client also does not re-send Eneks.
set -euo pipefail

ENEKS=$'\033[>4;2m\033[=1u'
ENFCS=$'\033[?1004h'

send_to_tty() {
  local tty="$1" seq="$2"
  # A client may disconnect between hook dispatch and this background write.
  [[ -w "$tty" ]] || return 0
  printf '%s' "$seq" > "$tty"
}

case "${1:-}" in
  --all)
    socket="${2:?usage: ensure_extkeys.sh [--all <socket_path> | <client_tty>]}"
    seq="$ENEKS"
    if [[ "$(tmux -S "$socket" show-option -sv focus-events)" == "on" ]]; then
      seq="${ENEKS}${ENFCS}"
    fi
    while IFS=$'\t' read -r ctrl term tty; do
      if [[ "$ctrl" == "0" && "$term" == "xterm-256color" && -n "$tty" ]]; then
        send_to_tty "$tty" "$seq"
      fi
    done < <(tmux -S "$socket" list-clients -F $'#{client_control_mode}\t#{client_termname}\t#{client_tty}')
    ;;
  "")
    echo "usage: ensure_extkeys.sh [--all <socket_path> | <client_tty>]" >&2
    exit 1
    ;;
  *)
    send_to_tty "$1" "$ENEKS"
    ;;
esac
