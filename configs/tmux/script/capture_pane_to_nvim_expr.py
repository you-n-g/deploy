#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Capture a tmux pane and print the nvim --remote-expr that opens it in a tab.

Run under uv rather than the ambient python3: tmux resolves python3 to the
system interpreter, which is 3.6 on this host, and a keybinding is a bad place
to discover that at runtime.
"""

import json
import subprocess
import sys
import time

source_pane = sys.argv[1]

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
vim.api.nvim_buf_set_name(buf, _A.title)
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].buflisted = false
vim.bo[buf].modifiable = true
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.bo[buf].modified = false
vim.bo[buf].modifiable = true
vim.cmd("keepjumps tab sbuffer " .. buf)
vim.cmd("keepjumps normal! G0")
return _A.title
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
    + "})"
)
