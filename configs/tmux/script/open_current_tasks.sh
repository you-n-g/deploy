#!/usr/bin/env bash
# Toggle a floating pane showing the session's tasks/CURRENT.md (project-mindmap
# `current` mode) in nvim. A floating pane rather than display-popup: a popup is
# modal and swallows every prefix key until it closes, while a floating pane is a
# real pane, so window switching and navigate-note's tmux links keep working.
#
# CURRENT.md is written by the session's orchestrator Agent into its repo, so the
# orchestrator window's cwd decides which repo to look in. Sessions without an
# orchestrator window use the invoking pane's cwd instead.
#
# usage: open_current_tasks.sh SESSION WINDOW_ID PANE_ID WORKDIR   (from a tmux binding)
set -euo pipefail

SESSION="${1:?usage: open_current_tasks.sh SESSION WINDOW_ID PANE_ID WORKDIR}"
WINDOW_ID="${2:?usage: open_current_tasks.sh SESSION WINDOW_ID PANE_ID WORKDIR}"
PANE_ID="${3:?usage: open_current_tasks.sh SESSION WINDOW_ID PANE_ID WORKDIR}"
WORKDIR="${4:?usage: open_current_tasks.sh SESSION WINDOW_ID PANE_ID WORKDIR}"

# One floating viewer per session, tagged with @current_tasks. Pressing the key
# again in the window that has it closes it; from another window it moves there.
in_this_window=""
while read -r pane window tag; do
  [[ "$tag" == "1" ]] || continue
  if [[ "$window" == "$WINDOW_ID" ]]; then
    in_this_window="$pane"
  else
    tmux kill-pane -t "$pane"
  fi
done < <(tmux list-panes -s -t "$SESSION" -F '#{pane_id} #{window_id} #{@current_tasks}')

if [[ -n "$in_this_window" ]]; then
  tmux kill-pane -t "$in_this_window"
  exit 0
fi

# window_name may carry an AI status prefix such as "● orchestrator".
ORCH_DIR="$(tmux list-panes -s -t "$SESSION" -F $'#{window_name}\t#{pane_current_path}' \
  | awk -F '\t' '$1 ~ /(^|[[:space:]])orchestrator$/ { print $2; exit }')"

if [[ -n "$ORCH_DIR" ]]; then
  SOURCE="orchestrator window ($ORCH_DIR)"
  LOOKUP_DIR="$ORCH_DIR"
else
  SOURCE="current pane ($WORKDIR)"
  LOOKUP_DIR="$WORKDIR"
fi

if ! REPO_ROOT="$(git -C "$LOOKUP_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "open_current_tasks.sh: $SOURCE is not inside a git repository" >&2
  exit 1
fi

FILE="$REPO_ROOT/tasks/CURRENT.md"
if [[ ! -f "$FILE" ]]; then
  echo "open_current_tasks.sh: $FILE does not exist (looked via $SOURCE); run project-mindmap in current mode first" >&2
  exit 1
fi

command -v nvim >/dev/null 2>&1 || { echo "open_current_tasks.sh: nvim not found" >&2; exit 1; }

# Full width, top half: every entry is one long line, so give it the whole
# width. tmux rejects left + width >= window_width ("size or position too
# large"), so leave one column each side. Size and position must be given at
# creation; floating panes cannot be moved afterwards.
win_w="$(tmux display-message -p -t "$PANE_ID" '#{window_width}')"
win_h="$(tmux display-message -p -t "$PANE_ID" '#{window_height}')"
pw=$(( win_w - 2 )); ph=$(( win_h / 2 ))
px=1; py=0

# Land the cursor on the invoking pane's own entry when it is a listed TMA
# Agent. Entries link as [[tmux://session:window_index.pane_index]]; a
# window-only link also counts. First match wins; no match keeps line 1.
target_index="$(tmux display-message -p -t "$PANE_ID" '#{window_index}.#{pane_index}')"
own_line="$(grep -n -m1 -F \
  -e "tmux://$SESSION:$target_index]]" \
  -e "tmux://$SESSION:${target_index%%.*}]]" \
  "$FILE" | cut -d: -f1 || true)"

# Close the viewer as soon as the user moves elsewhere inside tmux (other pane,
# window or session), so stale viewers never pile up. tmux forwards focus
# (focus-events on), but FocusLost also fires when the outer terminal loses
# focus; ask tmux whether this pane is still the focused one before quitting.
# Edits are saved first: it is the user's own to-do file.
# Kept on one line: a newline inside a +cmd argument would split it into
# separate Ex commands.
AUTO_CLOSE_LUA='vim.api.nvim_create_autocmd("FocusLost", { callback = function() local out = vim.fn.system({ "tmux", "display-message", "-p", "-t", vim.env.TMUX_PANE, "#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}" }) if vim.trim(out) ~= "1" then vim.cmd("silent! wall | qa!") end end })'

# navigate-note only enters nav-mode for files named nav.md (BufWinEnter autocmd
# in its NavMode group). Force-load the plugin, then fire that autocmd as if the
# buffer were nav.md so <tab>/<s-tab>/1-9/<m-cr> work on the tmux links here.
# :silent drops its "Enter/Entered nav-mode" prints, which would otherwise block
# on a hit-enter prompt at startup.
# DISABLE_VIM_LSP is honoured by lua/plugins/nvim-lspconfig.lua: no diagnostics in a read-mostly viewer.
fp="$(tmux new-pane -t "$PANE_ID" -c "$REPO_ROOT" -e DISABLE_VIM_LSP=1 \
  -x "$pw" -y "$ph" -X "$px" -Y "$py" -P -F '#{pane_id}' \
  nvim \
    '+lua require("lazy").load({ plugins = { "navigate-note.nvim" } })' \
    '+silent doautocmd NavMode BufWinEnter nav.md' \
    "+lua $AUTO_CLOSE_LUA" \
    "+${own_line:-1}" \
    "$FILE")"
tmux set-option -p -t "$fp" @current_tasks 1
