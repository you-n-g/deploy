local M = {}

local target_format = "#{session_name}:#{window_index}.#{pane_index}"
local pane_format = table.concat({
  target_format,
  "#{pane_id}",
  "#{window_name}",
  "#{pane_current_command}",
  "#{pane_current_path}",
}, "\t")

local function trim(value)
  return value:gsub("^%s*(.-)%s*$", "%1")
end

local function clean_field(value)
  return trim(value or ""):gsub("[\t\r\n]", " ")
end

local function completion_bounds(line, col)
  local before_cursor = line:sub(1, col - 1)
  local link_start = before_cursor:match(".*()%[%[tmux://") or before_cursor:match(".*()%[%[")
  if not link_start then
    return col, col, ""
  end

  local link_end = line:find("]]", col, true)
  local replace_until = link_end and link_end + 2 or col
  local query = line:sub(link_start, col - 1):gsub("^%[%[tmux://", ""):gsub("^%[%[", "")
  return link_start, replace_until, query
end

local function list_panes()
  if vim.fn.executable("tmux") ~= 1 then
    error("tmux_complete: tmux executable is required")
  end

  local output = vim.fn.system({ "tmux", "list-panes", "-a", "-F", pane_format })
  if vim.v.shell_error ~= 0 then
    error("tmux_complete: tmux list-panes failed: " .. trim(output))
  end

  local rows = {}
  for line in output:gmatch("[^\n]+") do
    local target, pane_id, window_name, command, path = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if not target then
      error("tmux_complete: unexpected tmux list-panes row: " .. line)
    end

    target = clean_field(target)
    pane_id = clean_field(pane_id)
    window_name = clean_field(window_name)
    command = clean_field(command)
    path = clean_field(path)

    table.insert(rows, string.format("%-24s %-8s %-24s %-12s %s", target, pane_id, window_name, command, path))
  end

  if #rows == 0 then
    error("tmux_complete: no tmux panes found")
  end

  return rows
end

function M.complete_pane()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local replace_at, replace_until, query = completion_bounds(line, col)

  require("fzf-lua").fzf_exec(list_panes(), {
    prompt = "tmux pane> ",
    query = query,
    fzf_opts = {
      ["--no-multi"] = true,
      ["--header"] = "Enter insert [[tmux://target]] | columns: target pane_id window command path",
      ["--preview"] = "tmux capture-pane -ep -S -200 -t {1} 2>/dev/null | tail -n 120",
    },
    winopts = { preview = { hidden = false } },
    complete = function(selected, _, original_line, _)
      if not selected[1] then
        return
      end

      local target = selected[1]:match("^(%S+)")
      if not target then
        error("tmux_complete: selected row has no pane target: " .. selected[1])
      end

      local link = string.format("[[tmux://%s]]", target)
      local before = replace_at > 1 and original_line:sub(1, replace_at - 1) or ""
      local after = original_line:sub(replace_until)
      return before .. link .. after, replace_at + #link - 2
    end,
  })
end

function M.setup()
  vim.keymap.set({ "i" }, "<C-x><C-t>", function()
    M.complete_pane()
  end, { silent = true, desc = "Complete navigate-note tmux pane link" })
end

M.setup()

return M
