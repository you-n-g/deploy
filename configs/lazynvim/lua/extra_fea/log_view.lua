--[[
Motivation of the plugin:
- Automatically generate the outline
- Easy navigation in outlines

Cheatsheets
- You can convert the log into plain text via
  - pip install ansi2txt
  - `cat V02.log | ansi2txt  > V02.plain.log`
]]


-- Define the regular expressions for the elements you want to match
local patterns = {
  -- { regex = "function%s+(%w+)", type = "Function" },
  -- { regex = "local%s+function%s+(%w+)", type = "Local Function" },
  -- { regex = "local%s+(%w+)%s*=", type = "Local Variable" },
  { regex = "Role:system", type = "❓system message" },
  { regex = "- Response:", type = "💬response message" },
}

-- Cache for outlines
local outline_cache = {}

-- Function to create the outline
local function create_outline()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check if the outline is already cached
  if outline_cache[filepath] then
    return outline_cache[filepath]
  end

  local outline = {}
  local type_idx = {}  -- record the number type
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    for _, pattern in ipairs(patterns) do
      local match = string.match(line, pattern.regex)
      if match then
        type_idx[pattern.type] = (type_idx[pattern.type] or 0) + 1
        table.insert(outline, { type = pattern.type, name = match, line = i, type_idx = type_idx[pattern.type]})
      end
    end
  end

  -- Cache the outline
  outline_cache[filepath] = outline
  return outline
end

-- Function to display the outline in a floating window
local function display_outline()
  local outline = create_outline()  -- TODO: do it in the background
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

  local last_item, last_idx, focus_line
  if outline[1].line <= current_line then
    for idx, item in ipairs(outline) do
      last_item = item
      last_idx = idx
      if item.line > current_line and idx - 2 >= 0 then
        vim.api.nvim_buf_add_highlight(bufnr, -1, 'Visual', idx - 2, 0, -1)
        focus_line = idx - 2
        break
      end
    end
  end
  if last_item ~= nil and last_item.line <= current_line then
    vim.api.nvim_buf_add_highlight(bufnr, -1, 'Visual', last_idx - 1, 0, -1)
    focus_line = last_idx - 1
  end

  local width = 50
  local height = #lines
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
  }
  local win_id = vim.api.nvim_open_win(bufnr, true, opts)

  if focus_line then
    vim.api.nvim_win_set_cursor(0, {focus_line + 1, 0}) -- navigate to the focused line
  end

  -- Make the buffer not modifiable
  vim.bo[bufnr].modifiable = false  -- Fixed the deprecated problem.
  -- Set up key mapping to navigate to the main content
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win_id)
      local line = line_map[cursor[1]]
      if line then
        vim.api.nvim_win_close(win_id, true)
        vim.api.nvim_win_set_cursor(0, {line, 0})
      end
    end,
  })
end


local function  set_style()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  -- make it read only and prevent saving to disk
  -- Saving large logfiles is time consuming
  vim.api.nvim_buf_set_option(bufnr, 'wrap', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
end


-- Map a key to display the outline
vim.keymap.set('n', '<localleader>lo', display_outline, { noremap = true, silent = true, desc = "Display Outline" })
vim.keymap.set('n', '<localleader>ls', set_style, { noremap = true, silent = true, desc = "Set Buffer Style" })

-- Function to navigate to the next item in the outline
local function navigate_next_item()
  local outline = create_outline()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  for _, item in ipairs(outline) do
    if item.line > current_line then
      vim.api.nvim_win_set_cursor(0, {item.line, 0})
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
      vim.api.nvim_win_set_cursor(0, {outline[i].line, 0})
      print(string.format("%s[%d]: %s (line %d)", item.type, item.type_idx, item.name, item.line))
      return
    end
  end
end

-- TODO: navigate to same type

-- Map keys to navigate to the next or previous item in the outline
vim.keymap.set('n', ']l', navigate_next_item, { noremap = true, silent = true, desc = "Navigate to Next Outline Item" })
vim.keymap.set('n', '[l', navigate_prev_item, { noremap = true, silent = true, desc = "Navigate to Previous Outline Item" })
