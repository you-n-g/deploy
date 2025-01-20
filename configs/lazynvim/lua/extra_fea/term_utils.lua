--[[
When we are in the terminal, map 'gf' to open the file under the cursor or selection.
But do not replace the terminal window. Open it in the last window that is not a terminal.
And then jump to that window.

TODO:
- [ ] Go to lines:
  - goto fzf if failed.
- [ ] Add command to the terminal. Use prompt matching and <cr> to determine.
- [ ] Support rdagent.oai.llm_utils:_create_chat_completion_inner_function:728 - Response
  - from current/gitroot/src
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

function M.get_largest_non_terminal_win()
  -- Get a list of all windows
  local wins = vim.api.nvim_list_wins()
  local largest_win = nil
  local max_area = 0
  -- Iterate over all windows to find the largest non-terminal window
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
    if buftype ~= "terminal" then
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

-- Function to append the current line to the largest non-terminal buffer
function M.append_current_line_to_largest_buf()
  local largest_win = M.get_largest_non_terminal_win()
  if largest_win ~= nil then
    local current_line = vim.api.nvim_get_current_line()
    local buf = vim.api.nvim_win_get_buf(largest_win)
    local cursor_pos = vim.api.nvim_win_get_cursor(largest_win)
    vim.api.nvim_buf_set_lines(buf, cursor_pos[1] - 1, cursor_pos[1] - 1, false, { current_line })
    print("Appended to buffer in window: " .. largest_win)
  else
    print("No suitable window found.")
  end
end

-- Store enabled state per buffer
local append_to_largest_buf_enabled = {}

function M.toggle_append_to_largest_buf()
  local buf = vim.api.nvim_get_current_buf()
  local buftype = vim.api.nvim_buf_get_option(buf, "buftype")

  if buftype ~= "terminal" then
    print("This feature only works in terminal buffers.")
    return
  end

  append_to_largest_buf_enabled[buf] = not append_to_largest_buf_enabled[buf]

  local key = '<M-x>'
  if append_to_largest_buf_enabled[buf] then
    vim.api.nvim_buf_set_keymap(
      buf,
      "t",
      key,
      '<cmd>lua require"extra_fea.term_utils".append_current_line_to_largest_buf()<CR><CR>',
      { noremap = true, silent = true }
    )
    print("Append to largest buffer feature enabled for this terminal.")
  else
    vim.api.nvim_buf_del_keymap(buf, "t", key)
    print("Append to largest buffer feature disabled for this terminal.")
  end
end

-- Map a key to toggle the feature
vim.api.nvim_set_keymap(
  "n",
  "<leader>ta",
  '<cmd>lua require"extra_fea.term_utils".toggle_append_to_largest_buf()<CR>',
  { noremap = true, silent = true }
)

function M.open_file_in_largest_non_terminal_win(force)
  local largest_win = M.get_largest_non_terminal_win()
  -- Attempt to extract a file path and line number from the surrounding text
  local file = vim.fn.expand("<cfile>")
  local line = nil
  local current_line = vim.api.nvim_get_current_line()
  -- Escape special characters in the file path for exact matching
  local escaped_file = file:gsub("([^%w])", "%%%1")
  local pattern = escaped_file .. "[^%d]*(%d+)"
  local match_start, match_end = string.find(current_line, pattern)
  if match_start and match_end then
    line = tonumber(string.match(current_line, pattern))
    -- Highlight the matched file path and line number temporarily
    local ns_id = vim.api.nvim_create_namespace("")
    local cur_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_add_highlight(cur_buf, ns_id, "Search", vim.fn.line(".") - 1, match_start - 1, match_end)
    vim.defer_fn(function()
      vim.api.nvim_buf_clear_namespace(cur_buf, ns_id, 0, -1)
    end, 500) -- Highlight for 500 milliseconds
  end

  -- If a largest non-terminal window was found, open the file there
  local buftype = vim.api.nvim_buf_get_option(0, "buftype")
  if force == true or buftype == "terminal" and largest_win ~= nil and file ~= "" then
    vim.api.nvim_set_current_win(largest_win)
    vim.cmd("edit " .. file)
    if line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
    end
  else
    -- Fallback to the original 'gf' behavior if no suitable window is found
    vim.cmd("normal! gf")
  end
end

-- vim.api.nvim_set_keymap('n', 'gf', '<cmd>lua require"extra_fea.term_utils".open_file_in_last_non_terminal_window()<CR>', { noremap = true, silent = true })

-- Map 'gf' in terminal mode to the function
vim.keymap.set(
  { "n", "v" },
  "gf",
  '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win()<CR>',
  { noremap = true, silent = true }
)
vim.keymap.set(
  { "n", "v" },
  "gF",
  '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win(true)<CR>',
  { noremap = true, silent = true }
)

function M.copy_last_terminal_command()
  -- TODO: working on it.
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Find the last line that starts with a command prompt pattern
    local last_command = nil
    for i = #lines, 1, -1 do
      local line = lines[i]
      if line:match("^%s*%$") then -- Assuming the command prompt ends with '$'
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
vim.api.nvim_set_keymap(
  "t",
  "<M-m>",
  '<cmd>lua require"extra_fea.term_utils".max_toggle_in_terminal()<CR>',
  { noremap = true, silent = true }
)

-- In addition to normal mode.
-- terminal usually come at button or right
vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Go to Upper Window(term)", remap = true })
vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Go to Upper Window(term)", remap = true })

local max_toggle_in_terminal_state = {} -- map from terminal buffer id to existing window id

function M.max_toggle_in_terminal()
  local current_buf = vim.api.nvim_get_current_buf()
  local existing_win = max_toggle_in_terminal_state[current_buf]

  if existing_win and vim.api.nvim_win_is_valid(existing_win) then
    -- Close existing window
    vim.api.nvim_win_close(existing_win, false)
    max_toggle_in_terminal_state[current_buf] = nil
    return
  end

  -- Open terminal in a new window
  -- TODO: dependencies on the external keymaps.
  local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n><leader><Tab>b ", true, true, true)
  vim.fn.feedkeys(keys, "t")

  -- Get the newly created window
  vim.defer_fn(function()
    -- waiting to get the new window
    local new_win = vim.api.nvim_get_current_win()
    max_toggle_in_terminal_state[current_buf] = new_win

    -- Clean up the state when the window is closed
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(new_win),
      once = true,
      callback = function()
        -- Iterate through all entries to find and remove the window
        for buf_id, win_id in pairs(max_toggle_in_terminal_state) do
          if win_id == new_win then
            max_toggle_in_terminal_state[buf_id] = nil
            break
          end
        end
      end,
    })
  end, 300)
end

-- Autocommand to set a buffer-local keymap for terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.api.nvim_buf_set_keymap(
      0,
      "n",
      "<leader>C",
      '<cmd>lua require"extra_fea.term_utils".copy_last_terminal_command()<CR>',
      { noremap = true, silent = true }
    )
  end,
})

return M
