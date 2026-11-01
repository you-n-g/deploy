#!/usr/bin/env bash
# The fork menu: every way of forking PANE's AI session, opened on CLIENT.
# prefix + f and prefix + M-f both run it (prefix f replaced tmux's default
# find-window). Keys follow vim's <C-w> layout keys, as in prefix t c / j / v:
#   t  a new window (vim: tab) -- first, so Enter right after the prefix key
#      picks it; T also puts the fork first in the auto-switch pane list
#   s / v  a split below (:split) / to the right (:vsplit) of PANE; wrapper
#      rename is disabled so the joined pane cannot restore its temporary
#      window name on exit
#   f  a floating pane over PANE's window, its top-right quarter
# Below them, / is the find-window that prefix f used to be (prompt for text,
# jump to a window whose name or content has it).
#
# usage: fork_menu.sh CLIENT PANE
set -euo pipefail

usage="usage: fork_menu.sh CLIENT PANE"
client="${1:?$usage}"
pane="$(tmux display-message -p -t "${2:?$usage}" '#{pane_id}')"
fork="$HOME/deploy/configs/tmux/ai/fork_ai_session.sh -q --target $pane"

tmux display-menu -c "$client" -t "$pane" -C 0 -T "#[align=centre] fork AI " -x C -y C \
  "(t)ab     fork 到新窗口  — 回车默认"          t "run-shell \"$fork\"" \
  "(T)ab     fork 到新窗口并放到 pane list 最前" T "run-shell \"$fork --prepend-sequence\"" \
  "(s)plit   fork 到下方分屏（:split）"          s "run-shell \"$fork --disable-tmux-rename --join-back stacked\"" \
  "(v)split  fork 到右侧分屏（:vsplit）"         v "run-shell \"$fork --disable-tmux-rename --join-back side-by-side\"" \
  "(f)loat   fork 到浮窗（右上角）"              f "run-shell \"$fork --float\"" \
  "" \
  "-其它" "" "" \
  "(/)       查找窗口（原 prefix f）"           / 'command-prompt -p "find window:" { find-window -Z "%%" }'
