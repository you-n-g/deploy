#!/usr/bin/env bash
# Put the TMA Agents that PANE just opened first in the auto-switch pane list.
# prefix a n, right after an agent says it started a new TMA window.
#
# A headless AI (headless_ai.sh, as auto_pend.sh uses) reads PANE's recent
# output against the live AI panes and names the ones PANE created. They are
# prepended in the order it names them, so its first answer ends up first.
# Windows a TMA Agent opened carry @tma_created; the AI sees that as a hint.
#
# Silent on success -- the window list shows the new order; a failure is
# reported on the status line (exit 0 from a key, so tmux's own
# "'...' returned 1" does not replace it).
#
# usage: prepend-new-tma.sh PANE            (start it in the background)
#        prepend-new-tma.sh --decide PANE   (the background half)
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
usage="usage: prepend-new-tma.sh [--decide] PANE"
decide=0
[[ "${1:-}" != --decide ]] || { decide=1; shift; }
pane="$(tmux display-message -p -t "${1:?$usage}" '#{pane_id}')"

if (( ! decide )); then
  printf -v job '%q ' "$script_dir/prepend-new-tma.sh" --decide "$pane"
  tmux run-shell -b "$job"
  exit 0
fi

fail() {
  tmux display-message -d 8000 "prefix a n: $1"
  [[ -t 2 ]] && exit 1
  exit 0
}

source "$script_dir/../ai/lib.sh"
tma=" $(_ai_tma_pane_ids | tr '\n' ' ') "
candidates="$(_ai_pane_rows -a | awk -F $'\t' -v skip="$pane" -v tma="$tma" '
  $4 != skip {
    made = index(tma, " " $4 " ") ? "  [TMA 开的窗口]" : ""
    printf "%s  %s  window=%s%s  %s\n", $4, $2, $3, made, $12
  }')"
[[ -n "$candidates" ]] || fail "没有别的 AI 窗口"
label="$(tmux display-message -p -t "$pane" '#{session_name}:#{window_index}.#{pane_index} #{window_name}')"

prompt="$(mktemp)"
answer="$(mktemp)"
errors="$(mktemp)"
trap 'rm -f "$prompt" "$answer" "$errors"' EXIT
{
  cat <<EOF
下面是 tmux 里一个 AI agent 窗口（$label）最近的输出。它可能刚新开了一个或几个 TMA Agent 窗口
（另开 tmux 窗口跑的 Claude / Codex，通常输出里会提到窗口名，比如 "我开了一个新 agent dim-reduct:analysis-xxx"）。
请从候选里找出它新开的那些窗口。

候选窗口（pane id、位置、窗口名、是否 TMA 开的、任务描述）：
$candidates

只输出 pane id，每行一个，最重要（或最先要看）的放第一行；不要解释、不要 Markdown。
pane id 必须来自上面的列表。它没有新开窗口时，只输出一行：none

窗口最近的输出：
EOF
  tmux capture-pane -p -J -t "$pane" -S -200 | sed '/^[[:space:]]*$/d' | tail -n 150
} > "$prompt"

"$script_dir/../script/headless_ai.sh" "$pane" < "$prompt" > "$answer" 2> "$errors" \
  || fail "AI 调用失败：$(grep -v '^[[:space:]]*$' "$errors" | tail -n 1)"

picked=()
while read -r id _; do
  [[ "$id" =~ ^%[0-9]+$ ]] || continue
  grep -q "^$id " <<< "$candidates" || fail "AI 选的 $id 不在候选里"
  picked+=("$id")
done < "$answer"
if (( ${#picked[@]} == 0 )); then
  grep -qx 'none' "$answer" && fail "AI 判断 $label 没有新开 TMA 窗口"
  fail "AI 回答无法解析：$(head -c 80 "$answer")"
fi

# prepend-current puts a pane first; going backwards leaves the first answer first.
for (( i = ${#picked[@]} - 1; i >= 0; i-- )); do
  "$script_dir/sequence.sh" prepend-current "${picked[$i]}"
done
