-- The text a Vim pane offers to prefix C-o (copy_last_message_to_learn.sh), run
-- in that nvim over RPC: the selection while it is in a visual mode (tmux keys
-- leave the mode alone), else every line of the current buffer.
local mode = vim.api.nvim_get_mode().mode
if mode:match("^[vV\22]") then -- \22 is Ctrl-V: blockwise visual
  return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
end
return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
