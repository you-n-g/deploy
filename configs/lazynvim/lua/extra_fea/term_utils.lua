--[[
When we are in the terminal, map 'gf' to open the file under the cursor or selection.
But do not replace the terminal window. Open it in the last window that is not a terminal.
And then jump to that window.
]]

local M = {}


-- NOTE: Deprecated: we don't need to record where we are from. We only need to open it in the largest non-terminal window.
-- local last_non_terminal_win = nil
-- function M.open_file_in_last_non_terminal_window()
--   -- Get the current window and buffer
--   local current_win = vim.api.nvim_get_current_win()
--   local buf = vim.api.nvim_win_get_buf(current_win)
--   local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
--
--   -- Check if the current buffer is a terminal
--   if buftype == 'terminal' then
--     -- If a non-terminal window was found, open the file there
--     local file = vim.fn.expand('<cfile>')
--     if file ~= '' then
--       if last_non_terminal_win then
--         vim.api.nvim_set_current_win(last_non_terminal_win)
--       end
--       vim.cmd('edit ' .. file)
--     end
--   else
--     -- Fallback to the original 'gf' behavior
--     vim.cmd('normal! gf')
--   end
-- end
--
-- -- Autocommand to record the last non-terminal buffer
-- vim.api.nvim_create_autocmd('BufEnter', {
--   callback = function()
--     local current_win = vim.api.nvim_get_current_win()
--     local buf = vim.api.nvim_win_get_buf(current_win)
--     local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
--     require"snacks".debug("current_win, buf, buftype:", current_win, buf, buftype)
--     if buftype ~= 'terminal' and buftype ~= "nofile" then
--       last_non_terminal_win = current_win
--     end
--   end
-- })

local function get_largest_non_terminal_win()
  -- Get a list of all windows
  local wins = vim.api.nvim_list_wins()
  local largest_win = nil
  local max_area = 0
  -- Iterate over all windows to find the largest non-terminal window
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
    if buftype ~= 'terminal' then
      local width = vim.api.nvim_win_get_width(win)
      local height = vim.api.nvim_win_get_height(win)
      local area = width * height
      if area > max_area then
        max_area = area
        largest_win = win
      end
    end
  end
  return largest_win
end

function M.open_file_in_largest_non_terminal_win()
  local largest_win = get_largest_non_terminal_win()
  local file = vim.fn.expand('<cfile>')

  require"snacks".debug("largest_win, file:", largest_win, file, vim.api.nvim_buf_get_option(0, 'buftype'))

  -- If a largest non-terminal window was found, open the file there
  if vim.api.nvim_buf_get_option(0, 'buftype') == 'terminal' and largest_win ~= nil  and file ~= '' then
    vim.api.nvim_set_current_win(largest_win)
    vim.cmd('edit ' .. file)
  else
    -- Fallback to the original 'gf' behavior if no suitable window is found
    vim.cmd('normal! gf')
  end
end

-- vim.api.nvim_set_keymap('n', 'gf', '<cmd>lua require"extra_fea.term_utils".open_file_in_last_non_terminal_window()<CR>', { noremap = true, silent = true })

-- Map 'gf' in terminal mode to the function
vim.keymap.set({'n', 'v'}, 'gf', '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win()<CR>', { noremap = true, silent = true })

return M