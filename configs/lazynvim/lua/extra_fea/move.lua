--[[
The motivation of the plugins.

Move the element (operant or words) in the current line in insert mode / normal mode.
- `alt + h` to swith current operant with the left one.
- `alt + l` to swith current operant with the right one.

If treesitter is installed, use treesitter to determine the operant.
otherwise, use the word to determine the operant.

For example, if the current line is:
- {"one", "two", "three"}

If your cursor is on the "one", you can use `alt + h` to switch it with "two".
]]

local M = {}

local SEGMENT_PATTERN = "[%w_-]+"

-----------------------------------------------------------
-- internal helpers
-----------------------------------------------------------
local function split_line_into_segments(line)
  -- segments are contiguous runs of [a-zA-Z0-9_]; everything else
  -- (spaces, punctuation, quotes, brackets …) is treated as separator
  local segs = {}
  local init = 1
  while true do
    local s_col, e_col = line:find(SEGMENT_PATTERN, init)
    if not s_col then break end
    local txt = line:sub(s_col, e_col)
    segs[#segs + 1] = {
      text  = txt,
      s_col = s_col,          -- 1-based
      e_col = e_col,          -- inclusive
    }
    init = e_col + 1
  end
  return segs
end

local function find_segment_at_col(segs, col)
  for i, seg in ipairs(segs) do
    if col >= seg.s_col and col <= seg.e_col then
      return i
    end
  end
end

local function swap_segments_in_line(line, segs, i, j)
  if not segs[i] or not segs[j] then return line end
  if i > j then  -- make sure i < j for easy slice handling
    i, j = j, i
  end
  local a, b = segs[i], segs[j]
  return table.concat({
    line:sub(1,  a.s_col - 1),
    b.text,
    line:sub(a.e_col + 1, b.s_col - 1),
    a.text,
    line:sub(b.e_col + 1),
  })
end

-----------------------------------------------------------
-- core action
-----------------------------------------------------------
local function perform_swap(direction)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  -- NOTE: we fall back to simple textual segments even when TS is present;
  -- using TS only for future extension.
  local segs   = split_line_into_segments(line)
  local idx    = find_segment_at_col(segs, col + 1)  -- seg indexes are 1-based
  if not idx then return end                          -- nothing to do

  local target = direction == "left" and idx - 1 or idx + 1
  if not segs[target] then return end                -- edge of line

  local new_line = swap_segments_in_line(line, segs, idx, target)
  vim.api.nvim_set_current_line(new_line)

  -- recalculate segments of the updated line and move cursor
  local segs_new = split_line_into_segments(new_line)
  local new_seg  = segs_new[target]
  if new_seg then
    vim.api.nvim_win_set_cursor(0, { row, new_seg.s_col - 1 })
  end
end

-----------------------------------------------------------
-- public API
-----------------------------------------------------------
function M.swap_left()  perform_swap("left")  end
function M.swap_right() perform_swap("right") end

-----------------------------------------------------------
-- key-mappings (only define once)
-----------------------------------------------------------
if not vim.g.__extra_fea_move_loaded then
  vim.g.__extra_fea_move_loaded = true

  -- NOTE: it conflicts with with the key mapping with `navigate-note.nvim` in normal mode.
  -- local map = function(mode, lhs, rhs, desc)
  --   vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
  -- end
  -- map("n", "<A-h>", M.swap_left,  "Swap element with left neighbor")
  -- map("n", "<A-l>", M.swap_right, "Swap element with right neighbor")

  vim.keymap.set("i", "<A-h>", function()
      vim.schedule(M.swap_left)   -- do the swap after this mapping finishes
      return ""                   -- insert nothing, stay in Insert mode
    end,
    { expr = true, silent = true, desc = "Swap element with left neighbor" })

  vim.keymap.set("i", "<A-l>", function()
      vim.schedule(M.swap_right)
      return ""
    end,
    { expr = true, silent = true, desc = "Swap element with right neighbor" })
end

return M
