#!/usr/bin/env bash
# Print the floating AI pane of HOST_PANE's window, creating it when there is
# none. A new one runs the TMUX_AI_TOOL wrapper (codexr / clauder) in the
# top-right quarter of the window, unfocused, and is printed only once the
# agent is up: its SessionStart hook has set @ai_agent_running
# (track_ai_agent_state.sh init), so text sent right after is not lost to a
# TUI that is still starting.
#
# usage: ensure_float_ai_pane.sh HOST_PANE
set -euo pipefail

host="${1:?usage: ensure_float_ai_pane.sh HOST_PANE}"
start_timeout_tenths=600

window="$(tmux display-message -p -t "$host" '#{window_id}')"
# The pane closes when its agent exits, so a tagged pane is a live one.
while read -r pane tag; do
  if [[ "$tag" == "1" ]]; then
    printf '%s\n' "$pane"
    exit 0
  fi
done < <(tmux list-panes -t "$window" -F '#{pane_id} #{@float_ai}')

ai_tool="$(tmux show-environment -g TMUX_AI_TOOL | sed 's/^TMUX_AI_TOOL=//')"
case "$ai_tool" in
  codex)  tool_cmd="codexr" ;;
  claude) tool_cmd="clauder" ;;
  *) echo "Unsupported TMUX_AI_TOOL: $ai_tool" >&2; exit 1 ;;
esac

read -r win_w win_h path < <(tmux display-message -p -t "$host" '#{window_width} #{window_height} #{pane_current_path}')
pw=$(( win_w / 2 )); ph=$(( win_h / 2 ))
px=$(( win_w - pw - 1 )); py=1
# Interactive zsh so rcfile's wrapper picks provider/model; no window rename,
# since the window belongs to the pane the AI floats over.
printf -v cmd 'TMUX_AI_DISABLE_RENAME=1 zsh -ic %q' "$tool_cmd"
pane="$("$(dirname -- "${BASH_SOURCE[0]}")/../script/new_float_pane.sh" "$host" \
  -d -x "$pw" -y "$ph" -X "$px" -Y "$py" -c "$path" "$cmd")"
tmux set-option -p -t "$pane" @float_ai 1

for (( i = 0; i < start_timeout_tenths; i++ )); do
  if ! tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
    echo "floating AI pane $pane exited while starting $tool_cmd" >&2
    exit 1
  fi
  if [[ -n "$(tmux show-option -pqv -t "$pane" @ai_agent_running)" ]]; then
    printf '%s\n' "$pane"
    exit 0
  fi
  sleep 0.1
done
echo "$tool_cmd in floating pane $pane did not start within $(( start_timeout_tenths / 10 ))s" >&2
exit 1
