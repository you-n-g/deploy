--[[
Remap `c-o` and `c-i`

Always create a hover window at the right top to show the jumps when we press `c-o` and `c-i`
- center the line that starts with ">" in the hover window
- hover window appear only for 3 seconds
- high light the content if it is in the current buffer

]]

local api = vim.api
local width = 60
local height = 10
local timeout = 2000

local hover_win = nil

-- Function to create hover window
local function create_hover_window()
  if hover_win and api.nvim_win_is_valid(hover_win) then
    api.nvim_win_close(hover_win, true)
  end
  local buf = api.nvim_create_buf(false, true)
  local win_opts = {
    style = "minimal",
    relative = "editor",
    row = 1,
    col = vim.o.columns - width - 1,
    width = width,
    height = height,
    border = "single",
    noautocmd = true,
  }
  hover_win = api.nvim_open_win(buf, false, win_opts)
  api.nvim_win_set_option(hover_win, "wrap", false)
  return buf, hover_win
end

-- Function to show jumps in hover window
local function show_jumps()
  local jumps = vim.fn.execute("jumps")
  local buf, win = create_hover_window()
  local lines = vim.split(jumps, "\n")

  -- Find the line that starts with ">"
  local target_line = 0
  for i, line in ipairs(lines) do
    if line:match("^>") then
      target_line = i - 1 -- Convert to 0-based index
      break
    end
  end

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  --for item in jumps_raw; if buffer number == current buffer number, then set the line highlight style as visual
  local jumps_raw = vim.fn.getjumplist()
  local current_buf = api.nvim_get_current_buf()
  local jump_list = jumps_raw[1]
  for i, jump in ipairs(jump_list) do
    if jump.bufnr == current_buf then
      api.nvim_buf_add_highlight(buf, -1, "Visual", i + 1, 0, -1) -- the first 2 lines are header
    end
  end

  -- Scroll the window to the target line
  api.nvim_win_set_cursor(win, { target_line + 1, 0 }) -- Convert back to 1-based index for set_cursor

  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end, timeout)
end

-- Remap `c-o` to show jumps
vim.api.nvim_set_keymap("n", "<C-o>", "", {
  noremap = true,
  silent = true,
  callback = function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "n", true)
    -- due to <C-o> will not take effect taht fast,we wait 100ms
    vim.defer_fn(function()
      show_jumps()
    end, 100)
  end,
})

-- Remap `c-i` to show jumps
vim.api.nvim_set_keymap("n", "<c-i>", "", {
  noremap = true,
  silent = true,
  callback = function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-i>", true, false, true), "n", true)
    -- due to <C-o> will not take effect taht fast,we wait 100ms
    vim.defer_fn(function()
      show_jumps()
    end, 100)
  end,
})
