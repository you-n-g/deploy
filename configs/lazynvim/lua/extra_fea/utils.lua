-- global functions

--- It will stop at the first nil
---@vararg: all kinds of variable yo want to inspect
function P(...)
  local args = {...}
  for i, v in ipairs(args) do
    print("Arg:", i)
    print(vim.inspect(v))
  end
end

-- TODO: get comprehensive information of current status.

-- module features
local M = {}

--- 
--- Get the visual selection in vim.
-- This function returns a table with the start and end positions of the visual selection.
--
-- We don't use  vim.fn.getpos("'<") because:
-- - https://www.reddit.com/r/neovim/comments/13mfta8/reliably_get_the_visual_selection_range/
-- - We must escape visual mode before make  "<" ">"  take effects
--
-- @return table containing the start and end positions of the visual selection
-- For example, it might return: { start = { row = 1, col = 5 }, ["end"] = { row = 3, col = 20 } }
function M.get_visual_selection()
  local pos = vim.fn.getpos("v")
  local begin_pos = { row = pos[2], col = pos[3] }
  pos = vim.fn.getpos(".")
  local end_pos = { row = pos[2], col = pos[3] }
  if ((begin_pos.row < end_pos.row) or ((begin_pos.row == end_pos.row) and (begin_pos.col <= end_pos.col))) then
    return { start = begin_pos, ["end"] = end_pos }
  else
    return { start = end_pos, ["end"] = begin_pos }
  end
end

return M
