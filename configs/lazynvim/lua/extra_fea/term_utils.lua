--[[
When we are in the terminal, map 'gf' to open the file under the cursor or selection.
But do not replace the terminal window. Open it in the last window that is not a terminal.
And then jump to that window.

TODO:
- [ ] Go to lines:
  - goto fzf if failed.
- [ ] Add command to the terminal. Use prompt matching and <cr> to determine.
- [ ] Support rdagent.oai.llm_utils:_create_chat_completion_inner_function:728 - Response
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

function M.open_file_in_largest_non_terminal_win(force)
  local largest_win = get_largest_non_terminal_win()
  -- Attempt to extract a file path and line number from the surrounding text
  local file = vim.fn.expand('<cfile>')
  local line = nil
  local current_line = vim.api.nvim_get_current_line()
  -- Escape special characters in the file path for exact matching
  local escaped_file = file:gsub("([^%w])", "%%%1")
  local pattern = escaped_file .. "[^%d]*(%d+)"
  local match_start, match_end = string.find(current_line, pattern)
  if match_start and match_end then
    line = tonumber(string.match(current_line, pattern))
    -- Highlight the matched file path and line number temporarily
    local ns_id = vim.api.nvim_create_namespace('')
    local cur_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_add_highlight(cur_buf, ns_id, 'Search', vim.fn.line('.') - 1, match_start - 1, match_end)
    vim.defer_fn(function()
      vim.api.nvim_buf_clear_namespace(cur_buf, ns_id, 0, -1)
    end, 500)  -- Highlight for 500 milliseconds
  end

  -- If a largest non-terminal window was found, open the file there
  local buftype = vim.api.nvim_buf_get_option(0, 'buftype')
  if force == true or buftype == 'terminal' and largest_win ~= nil  and file ~= '' then
    vim.api.nvim_set_current_win(largest_win)
    vim.cmd('edit ' .. file)
    if line then
      vim.api.nvim_win_set_cursor(0, {line, 0})
    end
  else
    -- Fallback to the original 'gf' behavior if no suitable window is found
    vim.cmd('normal! gf')
  end
end

-- vim.api.nvim_set_keymap('n', 'gf', '<cmd>lua require"extra_fea.term_utils".open_file_in_last_non_terminal_window()<CR>', { noremap = true, silent = true })

-- Map 'gf' in terminal mode to the function
vim.keymap.set({'n', 'v'}, 'gf', '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win()<CR>', { noremap = true, silent = true })
vim.keymap.set({'n', 'v'}, 'gF', '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win(true)<CR>', { noremap = true, silent = true })

-- Function to copy the last command from the terminal
function M.copy_last_terminal_command()
  -- TODO: working on it.
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_option(buf, 'buftype') == 'terminal' then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Find the last line that starts with a command prompt pattern
    local last_command = nil
    for i = #lines, 1, -1 do
      local line = lines[i]
      if line:match("^%s*%$") then  -- Assuming the command prompt ends with '$'
        last_command = lines[i + 1] or ""
        break
      end
    end

    if last_command and last_command ~= "" then
      vim.fn.setreg('"', last_command)
      print("Copied last command: " .. last_command)
    else
      print("No command found to copy.")
    end
  else
    print("Not in a terminal buffer.")
  end
end

-- This is for better showing the results for editing
-- Map Alt+m in terminal to perform a sequence of actions
vim.api.nvim_set_keymap('t', '<M-m>', '<cmd>lua require"extra_fea.term_utils".send_keys_in_terminal()<CR>', { noremap = true, silent = true })

-- In addition to normal mode.
-- terminal usually come at button or right
vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Go to Upper Window(term)", remap = true })
vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Go to Upper Window(term)", remap = true })

function M.send_keys_in_terminal()
  local keys = vim.api.nvim_replace_termcodes('<CR><C-\\><C-n><leader><Tab>b ', true, true, true)
  vim.fn.feedkeys(keys, 't')
end

-- Autocommand to set a buffer-local keymap for terminal buffers
vim.api.nvim_create_autocmd('TermOpen', {
  pattern = '*',
  callback = function()
    vim.api.nvim_buf_set_keymap(0, 'n', '<leader>C', '<cmd>lua require"extra_fea.term_utils".copy_last_terminal_command()<CR>', { noremap = true, silent = true })
  end
})

return M
