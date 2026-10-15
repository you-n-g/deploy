#!/usr/bin/env bash
# Pend PANE on whatever it is waiting for, worked out from its own output.
#
# For an agent that has handed its work to other agents and now only waits on
# them. PANE goes pending at once (reason "判定中…") and the user is moved on;
# in the background a headless AI reads PANE's recent output against the list
# of live AI panes and picks the one it waits on, and whether until that pane
# goes idle or until it is marked done. The reason then becomes the usual
# pend_until.sh one, so the release works as for prefix + M-p w / f.
#
# When the AI finds no AI pane to wait on, the reason becomes its short note
# of what PANE waits for (a plain pending, released by hand). The answer is
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

prompt="$(mktemp)"
answer="$(mktemp)"
errors="$(mktemp)"
trap 'rm -f "$prompt" "$answer" "$errors"' EXIT
{
  cat <<EOF
下面是 tmux 里一个 AI agent 窗口（$label）最近的输出。用户认为它已经把工作交出去了，
接下来只是在等别的 AI 窗口。请判断它在等哪一个窗口，以及等到什么时候。

候选窗口（pane id、位置、窗口名、状态、任务描述）：
$candidates

只输出一行，不要解释、不要 Markdown：
- 等某个窗口这一轮停下（它跑完一轮回到 idle 就能继续）：idle <pane id>
- 等某个窗口把整个任务做完（中间会停好几次，要它标记完成才算）：done <pane id>
- 等的不是上面任何窗口（比如等 Slurm 作业、等用户拍板）：none <不超过 15 个字的等待内容>
同时在等好几个窗口时，选最晚才会结束的那个。pane id 形如 %123，必须来自候选列表。

窗口最近的输出：
EOF
  tmux capture-pane -p -J -t "$pane" -S -200 | sed '/^[[:space:]]*$/d' | tail -n 150
} > "$prompt"

"$script_dir/headless_ai.sh" "$pane" < "$prompt" > "$answer" 2> "$errors" \
  || fail "AI 调用失败：$(grep -v '^[[:space:]]*$' "$errors" | tail -n 1)"
read -r mode rest < <(grep -m1 -E '^(idle|done|none)( |$)' "$answer" || true) || true
[[ -n "${mode:-}" ]] || fail "AI 回答无法解析：$(head -c 80 "$answer")"

still_ours || exit 0
case "$mode" in
  idle|done)
    target="${rest%% *}"
    grep -q "^$target " <<< "$candidates" || fail "AI 选的 $target 不在候选里"
    AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/pend_until.sh" "$mode" "$pane" "$target"
    # A done target needs no wait: pend_until.sh sets nothing, so release.
    if still_ours; then
      AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" wake "$pane"
    fi
    ;;
  none)
    AI_AGENT_STATE_SOURCE=auto-pend "$script_dir/track_ai_agent_state.sh" pending "$pane" "${rest:-/}"
    ;;
esac
tmux display-message "auto_pend $label → $(tmux show-option -pqv -t "$pane" @ai_agent_pending)"
