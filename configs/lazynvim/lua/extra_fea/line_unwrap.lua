--[[
When in nowrap mode,
automatically use virtual text to display the entire line at the current cursor position.
This plugin shows the full line content as virtual text when entering a line and clears it when leaving.
Enabled by default.
]]

local M = {}

local ns_id = vim.api.nvim_create_namespace("LineUnwrap")
local augroup_name = "LineUnwrapGroup"
local enabled = false
local last_line_by_buf = {}

local function is_supported_buf(bufnr)
  local bt = vim.bo[bufnr].buftype
  -- We want to support all kinds of buffers.
  -- if bt == "terminal" or bt == "nofile" or bt == "prompt" or bt == "help" or bt == "quickfix" then
  --   return false
  -- end
  return true
end

local function clear_buf(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
  end
end

local function get_line(bufnr, lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
  return lines[1] or ""
end

-- Return byte index (1-based) of first character whose start lies strictly beyond
-- the given display column (0-based) from the start of the line.
-- If the boundary falls in the middle of a wide/tab-expanded cell, we start from the next character,
-- so that no visible content is duplicated in the virtual text.
local function byte_index_from_display_col(s, target_col)
  local ts = vim.bo.tabstop
  local disp_col = 0
  local charlen = vim.fn.strcharlen(s)

  for ci = 1, charlen do
    local bi = vim.str_byteindex(s, ci - 1) + 1
    if disp_col >= target_col then
      return bi
    end
    local next_bi = vim.str_byteindex(s, ci) + 1
    local ch = s:sub(bi, next_bi - 1)
    local w
    if ch == "\t" then
      w = ts - (disp_col % ts)
    else
      w = vim.fn.strdisplaywidth(ch)
    end
    disp_col = disp_col + w
    if disp_col >= target_col then
      return next_bi
    end
  end
  return #s + 1
end

-- Truncate a string to at most max_cells display width (accounts for tabs and wide chars).
-- If reverse is true, truncate from the end and return the remaining content.
local function truncate_by_display_width(s, max_cells, reverse)
  if reverse ~= true then
    reverse = false
  end

  if max_cells <= 0 then
    return ""
  end
  local ts = vim.bo.tabstop
  local charlen = vim.fn.strcharlen(s)

  if not reverse then
    local disp_col = 0
    local cut_bi = #s + 1
    for ci = 1, charlen do
      local bi = vim.str_byteindex(s, ci - 1) + 1
      local next_bi = vim.str_byteindex(s, ci) + 1
      local ch = s:sub(bi, next_bi - 1)
      local w
      if ch == "\t" then
        w = ts - (disp_col % ts)
      else
        w = vim.fn.strdisplaywidth(ch)
      end
      if disp_col + w > max_cells then
        cut_bi = bi
        break
      end
      disp_col = disp_col + w
    end
    return s:sub(1, cut_bi - 1)
  else
    local disp_col = 0
    local cut_bi = 1
    for ci = charlen, 1, -1 do
      local bi = vim.str_byteindex(s, ci - 1) + 1
      local next_bi = vim.str_byteindex(s, ci) + 1
      local ch = s:sub(bi, next_bi - 1)
      local w
      if ch == "\t" then
        w = ts - (disp_col % ts)
      else
        w = vim.fn.strdisplaywidth(ch)
      end
      if disp_col + w > max_cells then
        cut_bi = next_bi
        break
      end
      disp_col = disp_col + w
    end
    return s:sub(cut_bi)
  end
end

-- Split a string into chunks of at most chunk_cells display width each.
-- Supports splitting from the end if reverse is true.
local function split_by_display_width(s, chunk_cells, reverse)
  local out = {}
  local rest = s
  if reverse == true then
    while rest ~= "" do
      local part = truncate_by_display_width(rest, chunk_cells, true)
      if part == "" then
        break
      end
      table.insert(out, 1, part)
      rest = rest:sub(1, #rest - #part)
    end
  else
    while rest ~= "" do
      local part = truncate_by_display_width(rest, chunk_cells)
      if part == "" then
        break
      end
      table.insert(out, part)
      rest = rest:sub(#part + 1)
    end
  end
  return out
end

local function show_virtual_line(bufnr, lnum)
  local line = get_line(bufnr, lnum)
  if line == "" then
    return
  end

  local win = vim.api.nvim_get_current_win()
  local view = vim.fn.winsaveview()
  local leftcol = view.leftcol or 0
  local wininfo = (vim.fn.getwininfo(win)[1] or {})
  local winw = wininfo.width or vim.api.nvim_win_get_width(win)
  local textoff = wininfo.textoff or 0
  local text_width = math.max(1, winw - textoff)
  local right_boundary = leftcol + text_width

  -- Only display invisible content on either side; if nothing is hidden, do nothing.
  local total_disp = vim.fn.strdisplaywidth(line)
  if leftcol == 0 and total_disp <= right_boundary then
    return
  end

  local head_budget = 10
  local tail_budget = 10

  -- HEAD: prepend the invisible head (content left of leftcol) above the line.
  if leftcol > 0 then
    local head_end_bi = byte_index_from_display_col(line, leftcol)
    local head = line:sub(1, head_end_bi - 1)
    if head ~= "" then
      local head_chunks_raw = split_by_display_width(head, math.max(1, text_width), true)
      -- Reorder so the first chunk is the one closest to the visible area (potentially non-full),
      -- followed by earlier chunks (typically full-width).
      local head_chunks = {}
      for i = 1, #head_chunks_raw do
        table.insert(head_chunks, head_chunks_raw[i])
      end

      local virt_lines_head = {}
      local head_limit = math.min(head_budget, #head_chunks)
      if head_limit > 0 then
        local function make_right_aligned(txt)
          local w = vim.fn.strdisplaywidth(txt)
          local pad = math.max(0, text_width - w)
          return { { string.rep(" ", pad), "NonText" }, { txt, "NonText" } }
        end
        local function pad_full_width(txt)
          local w = vim.fn.strdisplaywidth(txt)
          local pad = math.max(0, text_width - w)
          return { { txt .. string.rep(" ", pad), "NonText" } }
        end
        local remaining = #head_chunks - head_limit
        if remaining > 0 then
          table.insert(virt_lines_head, make_right_aligned(string.format("<.... %d lines ommited ...>", remaining)))
        end
        for i = remaining + 1, #head_chunks do
          if i == 1 then
            table.insert(virt_lines_head, make_right_aligned(head_chunks[i]))
          else
            table.insert(virt_lines_head, pad_full_width(head_chunks[i]))
          end
        end
      end
      if #virt_lines_head > 0 then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, 0, {
          virt_lines = virt_lines_head,
          virt_lines_above = true, -- prepend above the current line
          priority = 2048,
        })
      end
    end
  end

  -- TAIL: append the invisible tail (content right of visible window) below the line.
  if total_disp > right_boundary then
    local tail_start_bi = byte_index_from_display_col(line, right_boundary)
    local tail = line:sub(tail_start_bi)
    if tail ~= "" then
      local tail_chunks = split_by_display_width(tail, math.max(1, text_width))
      local virt_lines_tail = {}
      local tail_limit = math.min(tail_budget, #tail_chunks)
      if tail_limit > 0 then
        for i = 1, tail_limit do
          table.insert(virt_lines_tail, { { tail_chunks[i], "NonText" } })
        end
        local remaining = #tail_chunks - tail_limit
        if remaining > 0 then
          table.insert(virt_lines_tail, { { string.format("<.... %d lines ommited ...>", remaining), "NonText" } })
        end
      end
      if #virt_lines_tail > 0 then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, 0, {
          virt_lines = virt_lines_tail,
          virt_lines_above = false, -- append below the current line
          priority = 2048,
        })
      end
    end
  end
end

local function refresh_current_line()
  if not enabled then
    return
  end
  local win = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win)

  if not is_supported_buf(bufnr) then
    clear_buf(bufnr)
    last_line_by_buf[bufnr] = nil
    return
  end

  -- Only active in nowrap mode
  if vim.wo[win].wrap then
    clear_buf(bufnr)
    last_line_by_buf[bufnr] = nil
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(win)[1] - 1
  -- Always refresh to reflect horizontal scrolling and visibility changes.
  clear_buf(bufnr)
  show_virtual_line(bufnr, lnum)
end

function M.enable()
  if enabled then
    return
  end
  enabled = true
  local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = refresh_current_line,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = refresh_current_line,
  })

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = refresh_current_line,
  })
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = refresh_current_line,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    callback = function(args)
      clear_buf(args.buf)
      last_line_by_buf[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "wrap",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      clear_buf(bufnr)
      last_line_by_buf[bufnr] = nil
      refresh_current_line()
    end,
  })

  -- Initial refresh
  vim.schedule(refresh_current_line)
end

function M.disable()
  if not enabled then
    return
  end
  enabled = false
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      clear_buf(bufnr)
    end
  end
  last_line_by_buf = {}
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

-- Enable by default unless explicitly disabled
if vim.g.line_unwrap_auto_enable ~= false then
  if vim.fn.has("nvim") == 1 then
    M.enable()
  end
end

return M
