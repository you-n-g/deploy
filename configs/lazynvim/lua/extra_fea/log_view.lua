--[[
Motivation of the plugin:
- Automatically generate the outline
- Easy navigation in outlines

Cheatsheets
- You can convert the log into plain text via
  - pip install ansi2txt
  - `cat V02.log | ansi2txt  > V02.plain.log`
]]

local M = {}


-- Define the regular expressions for the elements you want to match
local patterns = {
  -- { regex = "function%s+(%w+)", type = "Function" },
  -- { regex = "local%s+function%s+(%w+)", type = "Local Function" },
  -- { regex = "local%s+(%w+)%s*=", type = "Local Variable" },
  -- Contents
  -- { regex = "Role:system", type = "    ❓system message" },
  { regex = "^Role:system", type = "    ❓system/user/prev message" },
  { regex = "^Role:user", type = "    ❓system/user/prev message" },
  { regex = "^Role:assistant", type = "    ❓system/user/prev message" },
  { regex = "- Response:", type = "    💬response message" },
  { regex = "- assistant:", type = "    💬response message" },
  { regex = "self.workspace_path", type = "    👾Code Workspace" },
  { regex = "^Task Name: [%w%s_]+", type = "      📝 Task Name" },
  { regex = "^name: [%w_]+", type = "      📝 Task Name" },
  -- Add matching line: Match exactly a line padded with spaces containing only "Run Info"
  { regex = " Run Info ", type = "    🚩 Run Info" },
  -- control
  { regex = "Implementing: ", type = "  🛠️Implementing" },
  { regex = "loop_index=%d*, step_index=%d*, step_name=[%w_]+", type = "♾️ Loop:" },
  -- - Handle content like `Start Loop 9, Step 4: record` (the line sometimes cover)
  { regex = "Start Loop %d+, Step %d+: [%w_]+", type = "♾️ Loop:" },
}

-- Cache for outlines
local outline_cache = {}


-- Find and highlight the focused outline line based on current cursor position
local function find_focused_outline_line(outline, current_line, bufnr)
  local last_item, last_idx, focus_line
  -- Use a dedicated namespace for our highlights to avoid clearing others
  local ns_id = vim.api.nvim_create_namespace('log_outline_visual')

  -- Clear all existing highlights in our namespace first
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- 1) highlight the outline item where the cursor is
  if outline[1].line <= current_line then
    for idx, item in ipairs(outline) do
      last_item = item
      last_idx = idx
      if item.line > current_line and idx - 2 >= 0 then
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Visual', idx - 2, 0, -1)
        focus_line = idx - 2
        break
      end
    end
  end
  if last_item ~= nil and last_item.line <= current_line then
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Visual', last_idx - 1, 0, -1)
    focus_line = last_idx - 1
  end

  -- 2) make sure the highlighted line is visible
  if focus_line then
    local win_id = vim.fn.bufwinid(bufnr) -- Get the window ID for the buffer
    if win_id ~= -1 then                  -- Check if the buffer is displayed in a window
      local top_line = vim.fn.line('w0', win_id)
      local bottom_line = vim.fn.line('w$', win_id)
      if focus_line + 1 < top_line or focus_line + 1 > bottom_line then
        vim.api.nvim_win_set_cursor(win_id, { focus_line + 1, 0 })
        -- vim.api.nvim_command('normal! zz') -- Center the line in the window
      end
    end
  end
  return focus_line
end


-- Function to create the outline
local function create_outline()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  -- Check if the outline is already cached
  if outline_cache[filepath] then
    return outline_cache[filepath]
  end

  local outline = {}
  local type_idx = {} -- record the number type
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    for _, pattern in ipairs(patterns) do
      local match = string.match(line, pattern.regex)
      if match then
        type_idx[pattern.type] = (type_idx[pattern.type] or 0) + 1
        table.insert(outline, { type = pattern.type, name = match, line = i, type_idx = type_idx[pattern.type] })
      end
    end
  end

  -- Cache the outline
  outline_cache[filepath] = outline
  return outline
end

-- Function to display the outline in a floating window
function M.display_outline()
  local cur_win_id = vim.api.nvim_get_current_win()
  local cur_bufnr = vim.api.nvim_get_current_buf()
  local outline = create_outline() -- TODO: do it in the background
  local lines = {}
  local line_map = {}
  for idx, item in ipairs(outline) do
    table.insert(lines, string.format("%s[%d]: %s (line %d)", item.type, item.type_idx, item.name, item.line))
    line_map[idx] = item.line
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Highlight the section line in the outline where the cursor is
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local focus_line = find_focused_outline_line(outline, current_line, bufnr)

  -- Setup cursor tracking to update highlights
  local group = vim.api.nvim_create_augroup('OutlineHighlight', {})
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = cur_bufnr,
    callback = function()
      -- Get current cursor position and update highlight
      local cursor_line = vim.api.nvim_win_get_cursor(cur_win_id)[1]
      find_focused_outline_line(outline, cursor_line, bufnr)
    end
  })

  -- Clean up when buffer is closed
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
    end
  })

  -- Calculate maximum width of outline content
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, #line)
  end
  -- Get current window width and calculate max allowed width
  local win_width = vim.api.nvim_win_get_width(0)
  local max_allowed = math.floor(win_width * 0.5)
  -- Add some padding and minimum width, but don't exceed half screen width
  local width = math.min(math.max(max_width + 2, 30), max_allowed)

  -- Create a vertical split on the left side
  vim.cmd('vsplit')
  local win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_id, bufnr)
  -- Set window width
  vim.api.nvim_win_set_width(win_id, width)
  -- Set window options
  vim.wo[win_id].number = false
  vim.wo[win_id].relativenumber = false
  vim.wo[win_id].wrap = false
  vim.wo[win_id].signcolumn = 'no'

  if focus_line then
    vim.api.nvim_win_set_cursor(0, { focus_line + 1, 0 }) -- navigate to the focused line
  end

  -- Make the buffer not modifiable
  vim.bo[bufnr].modifiable = false -- Fixed the deprecated problem.
  -- Set up key mapping to navigate to the main content
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win_id)
      local line = line_map[cursor[1]]
      if line then
        -- vim.api.nvim_win_close(win_id, true)
        vim.api.nvim_win_set_cursor(cur_win_id, { line, 0 })
        -- Move cursor to top of window in the correct window
        vim.api.nvim_win_call(cur_win_id, function()
          vim.cmd('normal! zt')
        end)
        find_focused_outline_line(outline, line, bufnr)
      end
    end,
  })

  -- I has to be at the end of the function, otherwise, style will not take effect.
  -- -- Highlight text like "loop_index=...", "step_index=...", "step_name=...", etc. for the outline buffer
  for idx, line in ipairs(lines) do
    for pat, hlgroup in pairs({
      ["loop_index=%d+"]           = "LogTimestamp",
      ["step_index=%d+"]           = "LogTimestamp",
      ["Start Loop %d+, Step %d+"] = "LogTimestamp",
    }) do
      local from, to = string.find(line, pat)
      if from and to then
        vim.api.nvim_buf_add_highlight(bufnr, -1, hlgroup, idx - 1, from - 1, to)
      end
    end
  end
  -- -- END highlight for items like "loop_index=1, step_index=1" for bufnr
end

-- Define highlight groups
vim.api.nvim_set_hl(0, 'LogTimestamp', { fg = '#FFA500', bold = true })
vim.api.nvim_set_hl(0, 'LogHeadingPattern', { fg = '#00FF00', bold = true })


function M.set_style()
  -- Private function to clean ANSI escape sequences and carriage returns from buffer lines
  local function clean_ansi_lines(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local cleaned_lines = {}
    for _, line in ipairs(lines) do
      local cleaned = line:gsub('\x1b%[[%d;?]*[mKGhl]', ''):gsub('\r', '')
      table.insert(cleaned_lines, cleaned)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, cleaned_lines)
  end
  local bufnr = vim.api.nvim_get_current_buf()

  clean_ansi_lines(bufnr)

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  -- make it read only and prevent saving to disk
  -- Saving large logfiles is time consuming
  -- vim.api.nvim_buf_set_option(bufnr, 'wrap', false)  -- Seems not necessary now.
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')

  -- Add timestamp highlighting
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  -- Highlight all patterns
  for i, line in ipairs(lines) do
    -- Timestamps
    local ts = string.match(line, '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d%d%d')
    if ts then
      local start = string.find(line, ts, nil, true)
      if start then
        vim.api.nvim_buf_add_highlight(bufnr, -1, 'LogTimestamp', i - 1, start - 1, start + #ts - 1)
      end
    end

    -- Pattern matches
    for _, pattern in ipairs(patterns) do
      local match = string.match(line, pattern.regex)
      if match then
        local start = string.find(line, match, nil, true)
        if start then
          vim.api.nvim_buf_add_highlight(bufnr, -1, 'LogHeadingPattern', i - 1, start - 1, start + #match - 1)
        end
      end
    end
  end
  -- Add gf mapping to open paths in new tab
  vim.keymap.set('n', 'gf', function()
    local path = vim.fn.expand('<cfile>')
    if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
      vim.cmd('tabnew ' .. path)
    else
      vim.notify('File or directory not found: ' .. path, vim.log.levels.WARN)
    end
  end, { buffer = true, desc = "Open file under cursor in new tab" })
end

-- Map a key to display the outline
vim.keymap.set('n', '<localleader>oo', M.display_outline, { noremap = true, silent = true, desc = "Display Outline" })
vim.keymap.set('n', '<localleader>os', M.set_style, { noremap = true, silent = true, desc = "Set Buffer Style" })

-- Function to navigate to the next item in the outline
local function navigate_next_item()
  local outline = create_outline()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  for _, item in ipairs(outline) do
    if item.line > current_line then
      vim.api.nvim_win_set_cursor(0, { item.line, 0 })
      print(string.format("%s[%d]: %s (line %d)", item.type, item.type_idx, item.name, item.line))
      return
    end
  end
end

-- Function to navigate to the previous item in the outline
local function navigate_prev_item()
  local outline = create_outline()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  for i = #outline, 1, -1 do
    if outline[i].line < current_line then
      local item = outline[i]
      vim.api.nvim_win_set_cursor(0, { outline[i].line, 0 })
      print(string.format("%s[%d]: %s (line %d)", item.type, item.type_idx, item.name, item.line))
      return
    end
  end
end

-- TODO: navigate to same type

-- Map keys to navigate to the next or previous item in the outline
vim.keymap.set('n', ']o', navigate_next_item, { noremap = true, silent = true, desc = "Navigate to Next Outline Item" })
vim.keymap.set('n', '[o', navigate_prev_item, {
  noremap = true,
  silent = true,
  desc = "Navigate to Previous Outline Item"
})

return M
