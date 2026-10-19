#!/usr/bin/env bash
# Close a TMA Agent whose task is done, keeping what it takes to bring it back.
#
# Appends a record to <project>/.tma/retired-agents.md -- time, window, tool,
# session id, working directory, SUMMARY and the resume command -- then closes
# the pane (its window too when it was the only pane). Resuming later in a new
# window picks the conversation up where it stopped:
#   clauder --resume <id>      codexr resume <id>
#
# The project is the git root of the pane's directory (the pane's directory when
# it is not in a repo). Refuses a pane that is running or has background work,
# and one whose session id cannot be found: closing it would lose the session.
#
# usage: retire_agent.sh PANE SUMMARY
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

usage="usage: retire_agent.sh PANE SUMMARY"
pane="$(tmux display-message -p -t "${1:?$usage}" '#{pane_id}')"
summary="${2:?$usage}"
fail() { echo "retire_agent: $1" >&2; exit 1; }

read -r running background < <(tmux display-message -p -t "$pane" '#{@ai_agent_running} #{@ai_agent_background}')
[[ "$running" != 1 && "$background" != 1 ]] || fail "$pane is running or has background work; wait for it to stop"

result="$(_find_ai_pid "$(tmux display-message -p -t "$pane" '#{pane_pid}')")" || fail "$pane runs no Claude/Codex"
tool="$(basename "${result##* }")"
session_id="$(_ai_session_id_for_pane "$pane")" || fail "no session id for $pane ($tool); not closing it"
case "$tool" in
  claude) resume="clauder --resume $session_id" ;;
  codex)  resume="codexr resume $session_id" ;;
  *) fail "unsupported AI tool: $tool" ;;
esac

IFS=$'\t' read -r label cwd panes < <(tmux display-message -p -t "$pane" \
  '#{session_name}:#{window_index}.#{pane_index} #{window_name}	#{pane_current_path}	#{window_panes}')
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
log="$root/.tma/retired-agents.md"
mkdir -p "$(dirname "$log")"
cat >>"$log" <<EOF

## $(date '+%Y-%m-%dT%H:%M:%S%z') $label

- 工具：$tool，会话 \`$session_id\`
- 目录：$cwd
- 任务：$summary
- 恢复：\`cd $cwd && $resume\`
EOF

if (( panes > 1 )); then
  tmux kill-pane -t "$pane"
else
  tmux kill-window -t "$pane"
fi
printf 'retired %s -> %s\nresume: cd %q && %s\n' "$label" "$log" "$cwd" "$resume"
