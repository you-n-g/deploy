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

local jump_ns = vim.api.nvim_create_namespace("term_utils_jump")

local function ensure_jump_highlights()
  vim.api.nvim_set_hl(0, "TermUtilsJumpMatch", { link = "IncSearch", default = true })
  vim.api.nvim_set_hl(0, "TermUtilsJumpRange", { link = "Search", default = true })
end

ensure_jump_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = ensure_jump_highlights,
})

-- NOTE: Deprecated: we don't need to record where we are from.
-- We only need to open it in the largest non-terminal window.
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

function M.normalize_path_for_edit(path)
  if path == nil or path == "" then
    return path
  end

  -- Expand ~/... and $VAR/... before checking existence or editing.
  return vim.fn.expand(path)
end

local function cursor_distance(match_start, match_end, cursor_idx)
  if not cursor_idx then
    return 0
  end
  if cursor_idx < match_start then
    return match_start - cursor_idx
  end
  if cursor_idx > match_end then
    return cursor_idx - match_end
  end
  return 0
end

local function extract_file_line_ref()
  local current_line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
  local raw_file = vim.fn.expand("<cfile>")
  local cursor_idx = cursor_col and cursor_col + 1 or nil
  local best_match = nil
  local best_distance = nil

  local function update_best_match(file, start_str, range_sep, end_str, match_start, match_end)
    local distance = cursor_distance(match_start, match_end, cursor_idx)
    local end_line = nil
    if range_sep == "-" and end_str ~= "" then
      end_line = tonumber(end_str)
    end

    if best_distance == nil or distance < best_distance then
      best_match = {
        file = file,
        start_line = tonumber(start_str),
        end_line = end_line,
        match_start = match_start,
        match_end = match_end,
      }
      best_distance = distance
    end

    return distance
  end

  -- Scan the whole line first. Depending on 'isfname' and cursor position,
  -- <cfile> may be the path, only the line number, or the "21-88" range.
  local pattern = "([^%s`'\"%(%)%[%]{}<>]+):(%d+)(%-?)(%d*)"
  local search_start = 1
  while true do
    local ms, me, file, start_str, range_sep, end_str = string.find(current_line, pattern, search_start)
    if not ms then
      break
    end

    if update_best_match(file, start_str, range_sep, end_str, ms, me) == 0 then
      break
    end

    search_start = me + 1
  end

  if best_match and (best_distance == 0 or raw_file == "" or raw_file:match("^%d+%-?%d*$")) then
    return best_match.file, best_match.start_line, best_match.end_line, best_match.match_start, best_match.match_end
  end

  return raw_file, nil, nil, nil, nil
end

local function open_tmux_link_with_navigate_note()
  local current_line = vim.api.nvim_get_current_line()
  local ok_utils, nav_utils = pcall(require, "navigate-note.utils")
  if not ok_utils or not nav_utils.is_tmux(current_line) then
    return false
  end

  local ok_tmux, nav_tmux = pcall(require, "navigate-note.tmux")
  if not ok_tmux then
    vim.notify("navigate-note tmux module is not available", vim.log.levels.ERROR)
    return true
  end

  nav_tmux.switch_to_tmux()
  return true
end

local function flash_text_range(buf, line, start_col, end_col, duration_ms)
  duration_ms = duration_ms or 900
  ensure_jump_highlights()

  local mark_id = vim.api.nvim_buf_set_extmark(buf, jump_ns, line - 1, start_col, {
    end_col = end_col,
    hl_group = "TermUtilsJumpMatch",
    priority = 10000,
  })

  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_del_extmark, buf, jump_ns, mark_id)
    end
  end, duration_ms)
end

-- Briefly highlight a range of lines in the current buffer
local function flash_line_range(start_line, end_line, duration_ms)
  end_line = end_line or start_line
  duration_ms = duration_ms or 900

  local win_height = vim.api.nvim_win_get_height(0)
  local range_height = end_line - start_line + 1
  local view = vim.fn.winsaveview()
  local target_topline = nil

  if range_height > win_height then
    target_topline = start_line
  else
    local visible_bottom = view.topline + win_height - 1
    if start_line < view.topline then
      target_topline = start_line
    elseif end_line > visible_bottom then
      local bottom_padding = math.min(2, win_height - range_height)
      target_topline = end_line + bottom_padding - win_height + 1
    end
  end

  if target_topline then
    view.topline = math.max(1, target_topline)
    vim.fn.winrestview(view)
  end

  local buf = vim.api.nvim_get_current_buf()
  ensure_jump_highlights()

  local mark_ids = {}
  for lnum = start_line, end_line do
    table.insert(mark_ids, vim.api.nvim_buf_set_extmark(buf, jump_ns, lnum - 1, 0, {
      line_hl_group = "TermUtilsJumpRange",
      priority = 10000,
    }))
  end

  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then
      for _, mark_id in ipairs(mark_ids) do
        pcall(vim.api.nvim_buf_del_extmark, buf, jump_ns, mark_id)
      end
    end
  end, duration_ms)
end

-- Function to append the current line to the largest non-terminal buffer
function M.append_current_line_to_largest_buf()
  local largest_win = M.get_largest_non_terminal_win()
  if largest_win ~= nil then
    local current_line = vim.api.nvim_get_current_line()
    local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
    local line_up_to_cursor = current_line:sub(1, cursor_col)
    local buf = vim.api.nvim_win_get_buf(largest_win)
    local cursor_pos = vim.api.nvim_win_get_cursor(largest_win)
    vim.api.nvim_buf_set_lines(buf, cursor_pos[1] - 1, cursor_pos[1] - 1, false, { line_up_to_cursor })
    print("Appended to buffer in window: " .. largest_win)
  else
    print("No suitable window found.")
  end
end

-- Store enabled state per buffer
local append_to_largest_buf_enabled = {}
local append_key = '<M-x>'

function M.toggle_append_to_largest_buf(enable, silent)
  local buf = vim.api.nvim_get_current_buf()
  local buftype = vim.api.nvim_buf_get_option(buf, "buftype")

  if buftype ~= "terminal" then
    if not silent then
      print("This feature only works in terminal buffers.")
    end
    return
  end

  append_to_largest_buf_enabled[buf] = enable or not append_to_largest_buf_enabled[buf]

  if append_to_largest_buf_enabled[buf] then
    vim.api.nvim_buf_set_keymap(
      buf,
      "t",
      append_key,
      '<cmd>lua require"extra_fea.term_utils".append_current_line_to_largest_buf()<CR><CR>',
      { noremap = true, silent = true }
    )
    if not silent then
      print("Append to largest buffer feature enabled for this terminal.")
    end
  else
    vim.api.nvim_buf_del_keymap(buf, "t", append_key)
    if not silent then
      print("Append to largest buffer feature disabled for this terminal.")
    end
  end
end

-- Map a key to toggle the feature
vim.api.nvim_set_keymap(
  "n",
  "<leader>ta",
  '<cmd>lua require"extra_fea.term_utils".toggle_append_to_largest_buf()<CR>',
  { noremap = true, silent = true, desc=string.format("Toggle Term Append(%s)", append_key) }
)

-- Enable append feature when creating terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    require("extra_fea.term_utils").toggle_append_to_largest_buf(true, true)
  end,
})


function M.open_file_in_largest_non_terminal_win(force)
  if open_tmux_link_with_navigate_note() then
    return
  end

  local largest_win = M.get_largest_non_terminal_win()
  -- Attempt to extract a file path and line number from the surrounding text
  local line = nil
  local extracted_file, start_line, end_line, match_start, match_end = extract_file_line_ref()
  local file = M.normalize_path_for_edit(extracted_file)

  -- If a largest non-terminal window was found, open the file there
  local buftype = vim.bo.buftype
  if largest_win ~= nil and (force == true or buftype == "terminal" and file ~= "") then
    -- 1. Goto the file and highlight it.
    if match_start then
      line = start_line
      -- Highlight the matched file path and line number temporarily
      local cur_buf = vim.api.nvim_get_current_buf()
      flash_text_range(cur_buf, vim.fn.line("."), match_start - 1, match_end)
    end

    -- 2. goto the file.
    vim.api.nvim_set_current_win(largest_win)
    vim.cmd("edit " .. vim.fn.fnameescape(file))
    if line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      flash_line_range(line, end_line)
    end
  else
    -- Fallback to the original 'gf' behavior if no suitable window is found
    vim.cmd("normal! gf")
  end
end

-- Normal mode gf: open file under cursor with optional line number extraction
function M.open_file_with_line_in_normal()
  if open_tmux_link_with_navigate_note() then
    return
  end

  local extracted_file, start_line, end_line, match_start, match_end = extract_file_line_ref()
  local file = M.normalize_path_for_edit(extracted_file)
  if file == "" then
    vim.cmd("normal! gf")
    return
  end

  -- Directories and symlinks to directories: let default gf handle them
  if vim.fn.isdirectory(file) == 1 then
    vim.cmd("normal! gf")
    return
  end

  -- If the file doesn't exist on disk, fall back to fzf-lua file search
  if vim.fn.filereadable(file) == 0 then
    local ok_fzf, fzf = pcall(require, "fzf-lua")
    if ok_fzf then
      fzf.files({ query = file })
    else
      vim.cmd("normal! gf")
    end
    return
  end

  local line = nil

  if match_start then
    line = start_line
    -- Briefly highlight the matched region
    local cur_buf = vim.api.nvim_get_current_buf()
    flash_text_range(cur_buf, vim.fn.line("."), match_start - 1, match_end)
  end

  -- Open in current window (normal gf behaviour), then jump to line
  local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file))
  if not ok then
    vim.cmd("normal! gf")
    return
  end
  if line then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    flash_line_range(line, end_line)
  end
end

vim.keymap.set("n", "gf", function()
  require("extra_fea.term_utils").open_file_with_line_in_normal()
end, { noremap = true, silent = true, desc = "Go to file (with line)" })

-- vim.api.nvim_set_keymap('n', 'gf',
--   '<cmd>lua require"extra_fea.term_utils".open_file_in_last_non_terminal_window()<CR>',
--   { noremap = true, silent = true })

-- Map 'gf' in terminal mode to the function
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function(args)
    local bufnr = args.buf
    vim.keymap.set(
      { "n", "v" },
      "gf",
      '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win()<CR>',
      { buffer = bufnr, noremap = true, silent = true }
    )
    vim.keymap.set(
      { "n", "v" },
      "gF",
      '<cmd>lua require"extra_fea.term_utils".open_file_in_largest_non_terminal_win(true)<CR>',
      { buffer = bufnr, noremap = true, silent = true }
    )
  end,
})

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
