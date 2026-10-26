#!/usr/bin/env bash
# Pend PANE on whatever it is waiting for, worked out from its own output.
#
# For an agent that has handed its work off -- to other agents or to a
# background process -- and now only waits. PANE goes pending at once (reason "判定中…") and the user is moved on;
# in the background a headless AI reads PANE's recent output against the list
# of live AI panes and picks the one it waits on. The reason then becomes the
# usual pend_until.sh "等 %id" one, so the release works as for prefix + M-p w.
#
# Always until idle, never until done: a pane is marked done only by hand, and
# agents seldom are, so a done wait would never release. Idle already means
# the work is over -- a turn that stops with background jobs still pending is
# background, not idle.
#
# The AI may also pick one of PANE's own background processes -- a job it runs,
# or a watcher it started to wait on something outside (a Slurm job, a file) --
# and PANE then waits for that pid to exit (pend_until.sh pid).
#
# When the AI finds nothing to wait on, the reason becomes its short note of
# what PANE waits for (a plain pending, released by hand). The answer is
# applied only while the reason is still "判定中…": a pending changed or
# cleared in the meantime is left alone.
#
# prefix + M-p a.
#
# usage: auto_pend.sh PANE            (pend, move on, decide in the background)
#        auto_pend.sh --decide PANE   (the background half)
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
placeholder="判定中…"
usage="usage: auto_pend.sh [--decide] PANE"

decide=0
if [[ "${1:-}" == "--decide" ]]; then
  decide=1
  shift
fi
pane="$(tmux display-message -p -t "${1:?$usage}" '#{pane_id}')"

if (( ! decide )); then
  AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" pending "$pane" "$placeholder"
  # The auto-switch loop moves on by itself on the pending event; without it,
  # move on here.
  if [[ -z "$(tmux show-option -gqv @auto_switch_mode_pid)" ]]; then
    "$script_dir/../auto-switch/switch-next.sh" --skip-pane "$pane" || true
  fi
  printf -v job '%q ' "$script_dir/auto_pend.sh" --decide "$pane"
  tmux run-shell -b "$job"
  exit 0
fi

still_ours() { [[ "$(tmux show-option -pqv -t "$pane" @ai_agent_pending 2>/dev/null)" == "$placeholder" ]]; }

fail() {
  still_ours && AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" pending "$pane" "自动判定失败"
  tmux display-message "auto_pend: $1"
  exit 1
}

# The candidates: every live AI pane but PANE itself, with what it is doing.
source "$script_dir/../ai/lib.sh"
candidates="$(_ai_pane_rows -a | awk -F $'\t' -v skip="$pane" '
  $4 != skip {
    state = $8 == 1 ? "running" : $9 == 1 ? "background" : $10 != "0" ? "pending" : "idle"
    printf "%s  %s  window=%s  state=%s  %s\n", $4, $2, $3, state, $12
  }')"
[[ -n "$candidates" ]] || fail "没有别的 AI 窗口可等"
label="$(tmux display-message -p -t "$pane" '#{session_name}:#{window_index}.#{pane_index} #{window_name}')"
# The pane's own background processes -- a job it runs, or a watcher it started
# to wait on something outside (a Slurm job, a file) -- each a candidate for a
# pid wait (pend_until.sh pid). The agent and its shells are left out.
processes="$(ps -u "$USER" -o pid=,ppid=,args= | awk -v root="$(tmux display-message -p -t "$pane" '#{pane_pid}')" '
  { pid = $1; parent[pid] = $2; $1 = $2 = ""; args[pid] = substr($0, 3) }
  END {
    for (pid in args) {
      for (p = parent[pid]; p in parent; p = parent[p]) if (p == root) break
      a = args[pid]
      # The agent itself and the shells around it; and sleep, the momentary
      # child of a watcher loop.
      if (p != root || a ~ /(^|\/)(claude|codex|node)( |$)|^-?zsh( |$)|zsh -ic|^sleep /) continue
      # A Claude Code background shell: show the command it evals.
      if (a ~ /shell-snapshots/ && match(a, /eval .*/)) a = substr(a, RSTART + 5)
      printf "%s  %s\n", pid, substr(a, 1, 160)
    }
  }')"

prompt="$(mktemp)"
answer="$(mktemp)"
errors="$(mktemp)"
trap 'rm -f "$prompt" "$answer" "$errors"' EXIT
{
  cat <<EOF
下面是 tmux 里一个 AI agent 窗口（$label）最近的输出。用户认为它已经把工作交出去了，
接下来只是在等。请判断它在等什么。

候选窗口（pane id、位置、窗口名、状态、任务描述）：
$candidates

它自己的后台进程（pid、命令；它跑的作业，或它为等外部事情——Slurm 作业、产物文件——起的 watcher）：
${processes:-（无）}

只输出一行，不要解释、不要 Markdown：
- 等某个窗口（它停下来、没有后台作业时就能继续）：idle <pane id>
- 等上面某个后台进程结束：pid <pid>
- 都不是（比如等用户拍板，或等的东西没有对应的进程）：none <不超过 15 个字的等待内容>
同时在等好几样时，选最晚才会结束的那个。pane id 形如 %123、pid 必须来自上面的列表。

窗口最近的输出：
EOF
  tmux capture-pane -p -J -t "$pane" -S -200 | sed '/^[[:space:]]*$/d' | tail -n 150
} > "$prompt"

"$script_dir/headless_ai.sh" "$pane" < "$prompt" > "$answer" 2> "$errors" \
  || fail "AI 调用失败：$(grep -v '^[[:space:]]*$' "$errors" | tail -n 1)"
read -r mode rest < <(grep -m1 -E '^(idle|pid|none)( |$)' "$answer" || true) || true
[[ -n "${mode:-}" ]] || fail "AI 回答无法解析：$(head -c 80 "$answer")"

still_ours || exit 0
case "$mode" in
  idle)
    target="${rest%% *}"
    grep -q "^$target " <<< "$candidates" || fail "AI 选的 $target 不在候选里"
    AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/pend_until.sh" --timeout 4h "$mode" "$pane" "$target"
    # A target already idle needs no wait: pend_until.sh sets nothing, so release.
    if still_ours; then
      AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" wake "$pane"
    fi
    ;;
  pid)
    target="${rest%% *}"
    grep -q "^$target " <<< "$processes" || fail "AI 选的进程 $target 不在候选里"
    AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/pend_until.sh" --timeout 12h pid "$pane" "$target"
    # Already gone: pend_until.sh sets nothing, so release.
    if still_ours; then
      AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" wake "$pane"
    fi
    ;;
  none)
    AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" pending "$pane" "${rest:-/}"
    ;;
esac
tmux display-message "auto_pend $label → $(tmux show-option -pqv -t "$pane" @ai_agent_pending)"
