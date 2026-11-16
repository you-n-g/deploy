#!/usr/bin/env bash
# Symmetric 1-to-1 pane bonding (@bond_pane): bond two panes (prefix + B) so
# you can jump back and forth between them (prefix + k b) or push/pull capture
# requests and code blocks to the bonded partner (prefix + t p b / l b,
# Vim \c<what>b / \c<what>B).
#
# Subcommands:
#   set    [-S SOCKET] SOURCE TARGET
#   target [-S SOCKET] [--quiet] [--format id|target|label] SOURCE
#   jump   [-S SOCKET] [--tmux-menu] [--client CLIENT] SOURCE
#   push   [-S SOCKET] [--tmux-menu] [--client CLIENT] SOURCE
#   pull   [-S SOCKET] [--tmux-menu] SOURCE
#   last   [-S SOCKET] [--tmux-menu] [--other-session] CLIENT SOURCE
#   pick   [-S SOCKET] session-ai|all-ai|session|all SOURCE
#   unbond [-S SOCKET] [--tmux-menu] SOURCE
#   cleanup [-S SOCKET]
#   menu   [-S SOCKET] CLIENT SOURCE
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
subcmd="${1:?usage: bond_pane.sh set|target|jump|push|pull|last|pick|unbond|cleanup|menu ...}"
shift

socket_opt=""
tmux_args=()
t() { tmux "${tmux_args[@]}" "$@"; }

quiet=0
tmux_menu=0
fmt=id
client=""
other_session=()
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -S) socket_opt="${2:?missing socket}"; tmux_args=(-S "$socket_opt"); shift 2 ;;
    --quiet) quiet=1; shift ;;
    --tmux-menu) tmux_menu=1; shift ;;
    --format) fmt="${2:?missing format}"; shift 2 ;;
    --client) client="${2:?missing client}"; shift 2 ;;
    --other-session) other_session=(--other-session); shift ;;
    --) shift; break ;;
    *) break ;;
  esac
done

report() {
  local msg="$1"
  (( quiet )) && return 0
  if [[ -n "$client" ]]; then
    t display-message -c "$client" -d 5000 "$msg" 2>/dev/null || t display-message -d 5000 "$msg" 2>/dev/null || true
  else
    t display-message -d 5000 "$msg" 2>/dev/null || true
  fi
}

# Never call fail inside $(...): subshell exit 0 would let the caller continue
# with an empty target. Under --tmux-menu (tmux run-shell), produce zero stdout
# and zero stderr and exit 0 -- any output or non-zero exit opens tmux view-mode.
fail() {
  report "bond: $1"
  if (( tmux_menu )); then
    exit 0
  fi
  (( quiet )) || printf 'bond: %s\n' "$1" >&2
  exit 1
}

pane_exists() {
  t list-panes -a -F '#{pane_id}' | grep -Fxq "$1"
}

resolve_pane_into() {
  local out_var="$1" raw="$2" id
  id="$(t display-message -p -t "$raw" '#{pane_id}' 2>/dev/null || true)"
  if [[ -z "$id" ]] || ! pane_exists "$id"; then
    return 1
  fi
  printf -v "$out_var" '%s' "$id"
}

pane_label() {
  t display-message -p -t "$1" '#{session_name}:#{window_index}.#{pane_index} #{window_name}'
}

detach_side() {
  local pane="$1" partner reverse
  partner="$(t show-option -pqv -t "$pane" @bond_pane 2>/dev/null || true)"
  t set-option -pqu -t "$pane" @bond_pane 2>/dev/null || true
  if [[ -n "$partner" ]] && pane_exists "$partner"; then
    reverse="$(t show-option -pqv -t "$partner" @bond_pane 2>/dev/null || true)"
    if [[ "$reverse" == "$pane" ]]; then
      t set-option -pqu -t "$partner" @bond_pane 2>/dev/null || true
    fi
  fi
}

do_set() {
  local src="" dst=""
  resolve_pane_into src "${1:?missing source pane}" || fail "找不到源 pane：$1"
  resolve_pane_into dst "${2:?missing target pane}" || fail "找不到目标 pane：$2"
  [[ "$src" != "$dst" ]] || fail "不能将 pane 与它自己绑定"
  detach_side "$src"
  detach_side "$dst"
  t set-option -pq -t "$src" @bond_pane "$dst" \; \
    set-option -pq -t "$dst" @bond_pane "$src"
  report "已双向绑定：$(pane_label "$src") ↔ $(pane_label "$dst")  [prefix k b 互跳]"
}

resolve_bonded_into() {
  local out_src="$1" out_partner="$2" raw_src="$3"
  local s="" p=""
  resolve_pane_into s "$raw_src" || fail "找不到 pane：$raw_src"
  p="$(t show-option -pqv -t "$s" @bond_pane 2>/dev/null || true)"
  [[ -n "$p" ]] || fail "当前 pane 尚未绑定目标（用 prefix + B 建立绑定）"
  if ! pane_exists "$p"; then
    t set-option -pqu -t "$s" @bond_pane 2>/dev/null || true
    fail "绑定的 pane $p 已关闭，已自动解除绑定"
  fi
  printf -v "$out_src" '%s' "$s"
  printf -v "$out_partner" '%s' "$p"
}

switch_to_pane() {
  local dst="${1:?missing destination pane}"
  if [[ -n "$client" ]]; then
    t switch-client -c "$client" -t "$dst"
  else
    t switch-client -t "$dst"
  fi
  "$script_dir/refresh_terminal_title.sh" >/dev/null 2>&1 || true
}

case "$subcmd" in
  set)
    do_set "${1:?missing source pane}" "${2:?missing target pane}"
    ;;
  target)
    src=""; partner=""
    resolve_bonded_into src partner "${1:?missing source pane}"
    case "$fmt" in
      id) printf '%s\n' "$partner" ;;
      target) t display-message -p -t "$partner" '#{session_name}:#{window_index}.#{pane_index}' ;;
      label) pane_label "$partner" ;;
      *) echo "unknown --format: $fmt" >&2; exit 2 ;;
    esac
    ;;
  jump)
    src=""; partner=""
    resolve_bonded_into src partner "${1:?missing source pane}"
    switch_to_pane "$partner"
    ;;
  push)
    src=""; partner=""
    resolve_bonded_into src partner "${1:?missing source pane}"
    req="$("$script_dir/capture_request.sh" "${tmux_args[@]}" "$src")"
    t send-keys -t "$partner" -l -- "$req"
    switch_to_pane "$partner"
    ;;
  pull)
    src=""; partner=""
    resolve_bonded_into src partner "${1:?missing source pane}"
    req="$("$script_dir/capture_request.sh" "${tmux_args[@]}" "$partner")"
    t send-keys -t "$src" -l -- "$req"
    ;;
  last)
    last_client="${1:?missing client}"
    raw_src="${2:?missing source pane}"
    socket_path="${socket_opt:-$(t display-message -p '#{socket_path}')}"
    if ! prev="$(python3 "$script_dir/jump_history.py" --socket "$socket_path" "${other_session[@]}" previous "$last_client" 2>&1)"; then
      client="$last_client" fail "$prev"
    fi
    client="$last_client" do_set "$raw_src" "$prev"
    ;;
  pick)
    # Runs inside open_float_pane.sh: report user-facing conditions via tmux
    # display-message and exit 0 so open_float_pane.sh closes cleanly instead
    # of holding open a black "exited with 1, press Enter to close" pane.
    tmux_menu=1
    scope="${1:?usage: bond_pane.sh pick session-ai|all-ai|session|all SOURCE_PANE}"
    src=""
    resolve_pane_into src "${2:?missing source pane}" || fail "找不到源 pane"
    session="$(t display-message -p -t "$src" '#{session_name}')"
    if [[ "$scope" == *-ai ]]; then
      picker="$script_dir/../ai/get_ai_pane.sh"
      rc=0
      if [[ "$scope" == all-ai ]]; then
        picked="$("$picker" -i -A)" || rc=$?
      else
        picked="$("$picker" -i "$session")" || rc=$?
      fi
      case "$rc" in
        0) ;;
        1) fail "没有可选的 AI pane（$scope）" ;;
        2) exit 0 ;;
        *) fail "选择 AI pane 失败（exit $rc）" ;;
      esac
      if [[ "$picked" == "$src" ]]; then
        fail "选中的是当前 pane 自己（$scope 里没有其它 AI pane）"
      fi
      do_set "$src" "$picked"
      exit 0
    fi
    case "$scope" in
      session) list_args=(-s -t "$session") ;;
      all) list_args=(-a) ;;
      *) fail "unknown pick scope: $scope" ;;
    esac
    rows="$(t list-panes "${list_args[@]}" -F \
      $'#{?@last_visit,#{@last_visit},0}\t#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{window_name}\t#{pane_current_command}\t#{pane_current_path}' \
      | awk -F '\t' -v a="$src" -v b="${TMUX_PANE:-}" '$2 != a && $2 != b' | sort -t $'\t' -k1,1nr)"
    if [[ -z "$rows" ]]; then
      fail "没有其它可选的 pane（$scope）"
    fi
    rc=0
    selected="$(printf '%s\n' "$rows" | cut -f2- | column -t -s $'\t' \
      | fzf --reverse --with-nth '2..' --header "双向绑定 ↔ 当前 pane（$scope）" \
          --preview 'tmux capture-pane -ept {1} | perl -0777 -pe "s/\s+\z/\n/"' \
          --preview-window 'up:60%,follow')" || rc=$?
    case "$rc" in
      0) ;;
      1|130) exit 0 ;;
      *) fail "fzf 选择失败（exit $rc）" ;;
    esac
    do_set "$src" "${selected%% *}"
    ;;
  unbond)
    src=""
    resolve_pane_into src "${1:?missing source pane}" || fail "找不到 pane：$1"
    existing="$(t show-option -pqv -t "$src" @bond_pane 2>/dev/null || true)"
    if [[ -z "$existing" ]]; then
      report "bond: 当前 pane 本来就没有绑定"
      exit 0
    fi
    detach_side "$src"
    report "已解除绑定"
    ;;
  cleanup)
    rows="$(t list-panes -a -F $'#{pane_id}\t#{@bond_pane}' 2>/dev/null || true)"
    [[ -n "$rows" ]] || exit 0
    stale="$(awk -F '\t' '
      { alive[$1] = 1; if ($2 != "") bond[$1] = $2 }
      END { for (p in bond) if (!(bond[p] in alive)) print p }
    ' <<<"$rows")"
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      t set-option -pqu -t "$p" @bond_pane 2>/dev/null || true
    done <<<"$stale"
    ;;
  menu)
    menu_client="${1:?missing client}"
    src=""
    tmux_menu=1
    client="$menu_client"
    resolve_pane_into src "${2:?missing source pane}" || fail "找不到当前 pane"
    socket_path="${socket_opt:-$(t display-message -p '#{socket_path}')}"
    partner_label="$("$0" target -S "$socket_path" --quiet --format label "$src" 2>/dev/null || true)"
    if [[ -n "$partner_label" ]]; then
      safe_label="${partner_label//#/##}"
      title="#[align=centre] 绑定：↔ ${safe_label} "
    else
      title="#[align=centre] 绑定 pane（未绑定） "
    fi
    printf -v q_self '%q' "$0"
    printf -v q_open '%q' "$script_dir/open_float_pane.sh"
    printf -v q_sock '%q' "$socket_path"
    printf -v q_cli '%q' "$menu_client"
    printf -v q_src '%q' "$src"
    t display-menu -c "$menu_client" -t "$src" -C 1 -T "$title" -x C -y C -- \
      "-建立双向绑定（小写=本 session，大写=所有/跨 session）" "" "" \
      "  (a)i       选本 session 的 AI 绑定  — 回车默认" a "run-shell \"$q_open --skip-jump-history $q_src $q_self pick -S $q_sock session-ai $q_src\"" \
      "  (A)I       选所有 session 的 AI 绑定"         A "run-shell \"$q_open --skip-jump-history $q_src $q_self pick -S $q_sock all-ai $q_src\"" \
      "  (s)ession  选本 session 的任意 pane 绑定"     s "run-shell \"$q_open --skip-jump-history $q_src $q_self pick -S $q_sock session $q_src\"" \
      "  (S)        选所有 session 的任意 pane 绑定"   S "run-shell \"$q_open --skip-jump-history $q_src $q_self pick -S $q_sock all $q_src\"" \
      "  (l)ast     绑定上一个访问的 pane"             l "run-shell \"$q_self last -S $q_sock --tmux-menu $q_cli $q_src\"" \
      "  (L)ast     绑定上一个 session 的最近 pane"    L "run-shell \"$q_self last -S $q_sock --tmux-menu --other-session $q_cli $q_src\"" \
      "" \
      "(u)nbond    解除当前绑定"                       u "run-shell \"$q_self unbond -S $q_sock --tmux-menu $q_src\""
    ;;
  *)
    echo "unknown bond_pane.sh subcommand: $subcmd" >&2
    exit 2
    ;;
esac
