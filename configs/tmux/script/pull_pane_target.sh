#!/usr/bin/env bash
# Pick a pane with fzf and type its capture request into PANE, without Enter:
# the reverse of send_current_target_to_ai.sh, which types PANE's request into
# an AI pane. Runs inside the floating pane open_float_pane.sh makes (prefix t),
# not a display-popup, so Esc reaches fzf; the float closes after the pick.
#
# SCOPE  session      panes of PANE's session
#        all          panes of every session
#        session-ai   AI panes of PANE's session
#        all-ai       AI panes of every session
# Plain scopes list panes here, most recently visited first (@last_visit); PANE
# and the float running this are left out. AI scopes use get_ai_pane.sh's
# picker instead, for its status column; it may offer PANE itself (and picks
# alone when there is a single AI pane), so picking PANE is refused.
#
# usage: pull_pane_target.sh SCOPE PANE
set -euo pipefail

usage="usage: pull_pane_target.sh session|all|session-ai|all-ai PANE"
scope="${1:?$usage}"
pane="${2:?$usage}"
session="$(tmux display-message -p -t "$pane" '#{session_name}')"

case "$scope" in
  session) list_args=(-s -t "$session") ;;
  all) list_args=(-a) ;;
  session-ai|all-ai) ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

insert_request() {
  local target
  target="$(tmux display-message -p -t "$1" '#{session_name}:#{window_index}.#{pane_index}')"
  tmux send-keys -t "$pane" -l "请capture我的Tmux的这个pane[$target]的内容"
}

if [[ "$scope" == *-ai ]]; then
  picker="$(dirname -- "${BASH_SOURCE[0]}")/../ai/get_ai_pane.sh"
  rc=0
  if [[ "$scope" == all-ai ]]; then
    picked="$("$picker" -i -A)" || rc=$?
  else
    picked="$("$picker" -i "$session")" || rc=$?
  fi
  # get_ai_pane.sh: 1 no AI pane, 2 cancelled.
  case "$rc" in
    0) ;;
    1) echo "没有 AI pane（$scope）" >&2; exit 1 ;;
    2) exit 0 ;;
    *) exit "$rc" ;;
  esac
  if [[ "$picked" == "$pane" ]]; then
    echo "选中的是当前 pane 自己（$scope 里可能只有它一个 AI pane）" >&2
    exit 1
  fi
  insert_request "$picked"
  exit 0
fi

rows="$(tmux list-panes "${list_args[@]}" -F \
  $'#{?@last_visit,#{@last_visit},0}\t#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{window_name}\t#{pane_current_command}\t#{pane_current_path}' \
  | awk -F '\t' -v a="$pane" -v b="${TMUX_PANE:-}" '$2 != a && $2 != b' | sort -t $'\t' -k1,1nr)"

if [[ -z "$rows" ]]; then
  echo "没有可选的 pane（$scope）" >&2
  exit 1
fi

rc=0
selected="$(printf '%s\n' "$rows" | cut -f2- | column -t -s $'\t' \
  | fzf --reverse --with-nth '2..' --header "拉入 → 这个 pane（$scope）" \
      --preview 'tmux capture-pane -ept {1} | perl -0777 -pe "s/\s+\z/\n/"' \
      --preview-window 'up:60%,follow')" || rc=$?
# 1: no match, 130: Esc / Ctrl-C -- nothing picked, close quietly.
case "$rc" in
  0) ;;
  1|130) exit 0 ;;
  *) exit "$rc" ;;
esac
insert_request "${selected%% *}"
