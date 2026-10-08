#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Capture a tmux pane and print the nvim --remote-expr that opens it in a tab.

With --here the buffer replaces the current window instead: for a fresh nvim
started just to show the capture, a new tab would leave an empty one beside it.

Run under uv rather than the ambient python3: tmux resolves python3 to the
system interpreter, which is 3.6 on this host, and a keybinding is a bad place
to discover that at runtime.
"""

import json
import subprocess
import sys
import time

args = sys.argv[1:]
here = "--here" in args
if here:
    args.remove("--here")
source_pane = args[0]

pane_height = subprocess.check_output(
    ["tmux", "display-message", "-p", "-t", source_pane, "#{pane_height}"],
    text=True,
).strip()
if not pane_height.isdigit():
    raise RuntimeError(f"invalid pane height: {pane_height!r}")

capture_start = f"-{max(int(pane_height), 1)}"
captured = subprocess.check_output(
    ["tmux", "capture-pane", "-p", "-t", source_pane, "-S", capture_start],
    text=True,
    errors="replace",
)
pane_label = subprocess.check_output(
    ["tmux", "display-message", "-p", "-t", source_pane, "#{session_name}:#{window_index}.#{pane_index}"],
    text=True,
).strip()

lines = captured.splitlines()
while lines and lines[-1].strip() == "":
    lines.pop()
if not lines:
    lines = [""]
title = f"tmux://{pane_label}/{int(time.time())}"

lua_code = r"""(function()
local lines = vim.fn.json_decode(_A.lines_json)
local buf = vim.api.nvim_create_buf(false, true)
-- The title has one-second resolution; a second capture of the same pane in
-- that second would collide with the first buffer's name.
local name, n = _A.title, 1
while vim.fn.bufexists(name) == 1 do
  n = n + 1
  name = _A.title .. "-" .. n
end
vim.api.nvim_buf_set_name(buf, name)
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].buflisted = false
vim.bo[buf].modifiable = true
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.bo[buf].modified = false
vim.bo[buf].modifiable = true
vim.cmd((_A.here == "1" and "keepjumps buffer " or "keepjumps tab sbuffer ") .. buf)
vim.cmd("keepjumps normal! G0")
return name
end)()
"""


def vim_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


print(
    "luaeval("
    + vim_string(lua_code)
    + ", {'lines_json': "
    + vim_string(json.dumps(lines, ensure_ascii=False))
    + ", 'title': "
    + vim_string(title)
    + ", 'here': "
    + vim_string("1" if here else "0")
    + "})"
)
