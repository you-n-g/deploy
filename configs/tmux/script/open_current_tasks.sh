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

# The full LazyVim config takes ~750 ms to start on this GPFS home (lazy spec
# loading alone ~430 ms); a viewer does not need any of it. Start nvim with no
# user config and put only navigate-note on the runtimepath: ~10 ms.
# The colorscheme is the same tokyonight-moon the full config uses; it costs
# ~4 ms because tokyonight caches its highlight table.
LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
NAV_NOTE_DIR="$LAZY_DIR/navigate-note.nvim"
THEME_DIR="$LAZY_DIR/tokyonight.nvim"
RENDER_MD_DIR="$LAZY_DIR/render-markdown.nvim"
[[ -f "$NAV_NOTE_DIR/lua/navigate-note/init.lua" ]] \
  || { echo "open_current_tasks.sh: navigate-note.nvim not found at $NAV_NOTE_DIR" >&2; exit 1; }
[[ -f "$THEME_DIR/colors/tokyonight-moon.lua" ]] \
  || { echo "open_current_tasks.sh: tokyonight.nvim not found at $THEME_DIR" >&2; exit 1; }
[[ -f "$RENDER_MD_DIR/lua/render-markdown/init.lua" ]] \
  || { echo "open_current_tasks.sh: render-markdown.nvim not found at $RENDER_MD_DIR" >&2; exit 1; }

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

# Make the current TMA stand out, not just the cursor line, at two strengths:
# the invoking pane's own entries (bright, ▶) and the rest of its window --
# sibling panes or a window-only link (faint, ▷). "SESSION:W." cannot match
# window W0..W9x, so fixed strings are enough.
pane_lines="$(grep -n -F -e "tmux://$SESSION:$target_index]]" "$FILE" \
  | cut -d: -f1 | paste -sd, - || true)"
window_lines="$(grep -n -F \
  -e "tmux://$SESSION:${target_index%%.*}." \
  -e "tmux://$SESSION:${target_index%%.*}]]" \
  "$FILE" | grep -v -F -e "tmux://$SESSION:$target_index]]" \
  | cut -d: -f1 | paste -sd, - || true)"
# Extmarks follow the text, so the marks stay on their entries if lines are
# edited above them. Set after the colorscheme so its groups are not reset.
HIGHLIGHT_LUA="local ns = vim.api.nvim_create_namespace('current_tma') vim.api.nvim_set_hl(0, 'CurrentTmaPane', { bg = '#3d5a80', bold = true }) vim.api.nvim_set_hl(0, 'CurrentTmaWindow', { bg = '#283347' }) local function mark(lines, group, sign, sign_group) for _, l in ipairs(lines) do vim.api.nvim_buf_set_extmark(0, ns, l - 1, 0, { line_hl_group = group, sign_text = sign, sign_hl_group = sign_group }) end end mark({ $pane_lines }, 'CurrentTmaPane', '▶', 'DiagnosticWarn') mark({ $window_lines }, 'CurrentTmaWindow', '▷', 'Comment')"

# Close the viewer as soon as the user moves elsewhere inside tmux (other pane,
# window or session), so stale viewers never pile up. tmux forwards focus
# (focus-events on), but FocusLost also fires when the outer terminal loses
# focus; ask tmux whether this pane is still the focused one before quitting.
# Edits are saved first: it is the user's own to-do file.
# Kept on one line: a newline inside a +cmd argument would split it into
# separate Ex commands.
AUTO_CLOSE_LUA='vim.api.nvim_create_autocmd("FocusLost", { callback = function() local out = vim.fn.system({ "tmux", "display-message", "-p", "-t", vim.env.TMUX_PANE, "#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}" }) if vim.trim(out) ~= "1" then vim.cmd("silent! wall | qa!") end end })'

# -u NONE implies --noplugin, so render-markdown's plugin/ entry (which
# registers its FileType attach) is sourced explicitly before the file loads.
# navigate-note only enters nav-mode for files named nav.md (BufWinEnter autocmd
# in its NavMode group). After setup(), fire that autocmd as if the buffer were
# nav.md so <tab>/<s-tab>/1-9/<m-cr> work on the tmux links here. :silent drops
# its "Enter/Entered nav-mode" prints, which would otherwise block on a
# hit-enter prompt at startup. -i NONE skips shada read/write on GPFS.
fp="$(tmux new-pane -t "$PANE_ID" -c "$REPO_ROOT" \
  -x "$pw" -y "$ph" -X "$px" -Y "$py" -P -F '#{pane_id}' \
  nvim -u NONE -i NONE \
    --cmd "set runtimepath^=$NAV_NOTE_DIR,$THEME_DIR,$RENDER_MD_DIR" \
    --cmd 'filetype plugin on | syntax on | runtime plugin/render-markdown.lua' \
    '+set termguicolors | colorscheme tokyonight-moon' \
    '+lua require("navigate-note").setup({ enable_block = true })' \
    '+silent doautocmd NavMode BufWinEnter nav.md' \
    '+nnoremap <buffer> q <Cmd>silent! wall <Bar> qa!<CR>' \
    "+lua $AUTO_CLOSE_LUA" \
    "+lua $HIGHLIGHT_LUA" \
    "+${own_line:-1}" \
    "$FILE")"
tmux set-option -p -t "$fp" @current_tasks 1
