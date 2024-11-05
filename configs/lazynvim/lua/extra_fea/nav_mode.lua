--[[
This is a vim plugin.

When we enter a file named `nav.md`, it will switch into nav-mode in the buffer.
You will navigate to the next `file:line` pattern in the `nav.md` when I press <tab>.
When I press <enter> when I'm on `file:line`, enter the according file and line.
It will leave the nav-mode if I leave the buffer.

When I'm not in nav-mode, `<localleader>na` will add a new line `file:line` (i.e. the position of current file) into the file `nav.md`.

`<localleader>nn` will open the `nav.md`.

Here is an example of `nav.md`
```markdown
- `start.sh:30`:  the entrance of the project
- `src/utils.py:40`: important utils
```
]]

local api = vim.api
local nav_md_file = "nav.md"


local file_line_pattern = "`([^:`]+):?(%d*)`"

-- Function to return all {line_number, start_pos, end_pos} in appearing order
local function get_all_matched(content)
  local matches = {}
  local line_number = 1

  -- Iterate through each line, including blank lines
  for line in content:gmatch("([^\r\n]*)\r?\n?") do
    local start_pos, end_pos = 0, 0
    while true do
      start_pos, end_pos = string.find(line, file_line_pattern, end_pos + 1)
      if not start_pos then break end
      table.insert(matches, {line_number, start_pos - 1, end_pos - 1}) -- -1 to align with the (0, 1) based pos
    end
    line_number = line_number + 1
  end

  return matches
end

local function navigate_to_next(reverse)
  local cursor_pos = api.nvim_win_get_cursor(0)

  -- Get all matches in the current buffer
  local buffer_content = table.concat(api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local matches = get_all_matched(buffer_content)
  if #matches == 0 then
    print("No file:line patterns found")
    return
  end

  local found = false
  if reverse then
    -- Find the previous match
    for i = #matches, 1, -1 do
      local match = matches[i]
      if match[1] < cursor_pos[1] or match[1] == cursor_pos[1] and cursor_pos[2] > match[3] then
        api.nvim_win_set_cursor(0, {match[1], match[2]})
        found = true
        break
      end
    end

    if not found then
      api.nvim_win_set_cursor(0, {matches[#matches][1], matches[#matches][2]})
    end
  else
    -- Find the next match
    for _, match in ipairs(matches) do
      if match[1] > cursor_pos[1] or match[1] == cursor_pos[1] and cursor_pos[2] < match[2] then
        api.nvim_win_set_cursor(0, {match[1], match[2]})
        found = true
        break
      end
    end

    if not found then
      api.nvim_win_set_cursor(0, {matches[1][1], matches[1][2]})
    end
  end
end

local function navigate_to_prev()
  navigate_to_next(true)
end


-- Function to open the file and line under cursor
local function open_file_line()
  local current_line = api.nvim_get_current_line()
  -- match pattern like `src/utils.py:40` or `src/utils.py`
  local file, line = string.match(current_line, file_line_pattern)
  if file then
    api.nvim_command('edit ' .. file)
    if line and line ~= "" then
      api.nvim_win_set_cursor(0, {tonumber(line), 0})
    else
      print("Opened file: " .. file .. " (no specific line number provided)")
    end
  else
    print("No valid file:line pattern under cursor")
  end
end

-- Function to add a new file:line entry to nav.md
local function add_file_line()
  local file = vim.fn.expand('%:p')
  local line = vim.fn.line('.')
  local entry = string.format("`%s:%d`", file, line)
  
  -- Open nav.md and append the new entry
  local f = io.open(nav_md_file, "a")
  if f then
    f:write(entry .. "\n")
    f:close()
    print("Added entry to nav.md: " .. entry)
  else
    print("Failed to open nav.md")
  end
end

-- Function to open nav.md
local function open_nav_md()
  if vim.fn.expand('%:t') == 'nav.md' then
    -- If we are already in nav.md, go to the previous file by pressing "<C-^>"
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-^>", true, false, true), 'n', true)
  else
    vim.cmd('edit ' .. nav_md_file)
  end
end

-- Function to enter nav-mode
local function enter_nav_mode()
  vim.keymap.set('n', '<Tab>', navigate_to_next, { noremap = true, silent = true, buffer=true })
  vim.keymap.set('n', '<S-Tab>', navigate_to_prev, { noremap = true, silent = true, buffer=true  })
  vim.keymap.set('n', '<CR>', open_file_line, { noremap = true, silent = true, buffer=true  })
  print("Entered nav-mode")
end

-- Function to leave nav-mode
local function leave_nav_mode()
  print("Left nav-mode")
end

-- Autocommand to enter nav-mode when nav.md is opened
local nav_mode_group = vim.api.nvim_create_augroup("NavMode", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = nav_md_file,
  callback = enter_nav_mode,
  group = nav_mode_group,
})
vim.api.nvim_create_autocmd("BufLeave", {
  pattern = nav_md_file,
  callback = leave_nav_mode,
  group = nav_mode_group,
})

-- Key mappings
vim.keymap.set('n', '<localleader>na', add_file_line, { noremap = true, silent = true })
vim.keymap.set('n', '<m-h>', open_nav_md, { noremap = true, silent = true })
