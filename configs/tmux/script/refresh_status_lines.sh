#!/usr/bin/env bash

set -eu

session="${1:-}"
if [ -z "$session" ]; then
  session="$(tmux display-message -p '#{session_name}')"
fi

client_width="$(
  # Use the narrowest attached client so the session layout stays usable on all
  # clients that are currently viewing it.
  tmux list-clients -t "${session}:" -F '#{client_width}' 2>/dev/null \
    | awk 'NF { if (min == "" || $1 < min) min = $1 } END { print min }'
)"

if [ -z "$client_width" ]; then
  exit 0
fi

visible_width() {
  sed -E 's/#\[[^]]*\]//g; s/\x1b\[[0-9;]*m//g' | awk '{ total += length($0) } END { print total + 0 }'
}

format_width() {
  tmux display-message -p -t "${session}:" "$1" 2>/dev/null | visible_width
}

estimate_non_window_width() {
  fixed_right_width="$(tmux show-options -gqv @status-non-window-fixed-right-width 2>/dev/null || true)"
  case "$fixed_right_width" in
    ''|*[!0-9]*)
      fixed_right_width=58
      ;;
  esac

  left_width="$(format_width '#{E:status-left}')"
  host_width="$(tmux display-message -p -t "${session}:" '#h' 2>/dev/null | visible_width)"
  echo $((left_width + host_width + fixed_right_width))
}

non_window_width="$(tmux show-options -gqv @status-window-second-line-reserve 2>/dev/null || true)"
case "$non_window_width" in
  ''|auto)
    non_window_width="$(estimate_non_window_width)"
    ;;
  *[!0-9]*)
    tmux display-message "Invalid @status-window-second-line-reserve: ${non_window_width}" 2>/dev/null || true
    exit 1
    ;;
esac

# Width model for deciding whether the window list needs a second status line:
#
#   <----------------------------- client_width ----------------------------->
#   [ buttons + right status + slack ][          free for windows           ]
#   <----- non_window_width ------->
#   <-------------------------- 90% of client_width ------------------------>
#
# In auto mode, non_window_width is estimated as:
#   visible(status-left) + visible(hostname) + @status-non-window-fixed-right-width
#
# If non_window_width already crosses 90% of the client width, there is less
# than 10% space left for window labels, so give the window list a second line.
max_one_line_width=$((client_width * 90 / 100))

# echo $non_window_width $max_one_line_width

if [ "$non_window_width" -gt "$max_one_line_width" ]; then
  tmux set-option -t "${session}:" status 2 >/dev/null
else
  tmux set-option -t "${session}:" status on >/dev/null
fi
