-- Loaded after the user's normal Neovim config, like the QA viewer.
local report

local function refresh()
  local view = vim.fn.winsaveview()
  local old = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local new = vim.fn.readfile(report)
  local hunks = vim.diff(table.concat(old, "\n") .. "\n", table.concat(new, "\n") .. "\n", {
    result_type = "indices",
  })
  for i = #hunks, 1, -1 do
    local h = hunks[i]
    local start = h[1] - (h[2] > 0 and 1 or 0)
    local replacement = vim.list_slice(new, h[3], h[3] + h[4] - 1)
    vim.api.nvim_buf_set_lines(0, start, start + h[2], false, replacement)
  end
  vim.bo.modified = false
  vim.cmd.checktime()
  vim.fn.winrestview(view)
end

local function setup_report()
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.breakindent = true
  vim.wo.foldenable = false
  vim.wo.signcolumn = "yes"
  vim.bo.modeline = false
  vim.bo.swapfile = false
  vim.diagnostic.enable(false, { bufnr = 0 })
  vim.keymap.set("n", "]]", function() vim.fn.search("^## ", "W") end, { buffer = true })
  vim.keymap.set("n", "[[", function() vim.fn.search("^## ", "bW") end, { buffer = true })
  vim.keymap.set("n", "<CR>", function()
    local target = vim.api.nvim_get_current_line():match("tmux://([^%]|%s]+)")
    if target then
      local result = vim.fn.system({ "tmux", "select-window", "-t", target })
      if vim.v.shell_error ~= 0 then error(result) end
      result = vim.fn.system({ "tmux", "select-pane", "-t", target })
      if vim.v.shell_error ~= 0 then error(result) end
    end
  end, { buffer = true })
end

function _G.research_leader_open(payload)
  local request = vim.json.decode(payload)
  if vim.bo.modified then
    error("Research note has unsaved edits; save or merge them before refreshing")
  end
  report = request.report
  -- Each viewer has its own Neovim process. This also covers lazy Git attachment.
  require("gitsigns").change_base(request.base, true)
  if vim.api.nvim_buf_get_name(0) == report then
    refresh()
  else
    vim.cmd.stopinsert()
    vim.api.nvim_cmd({ cmd = "edit", args = { report }, magic = { file = false, bar = false } }, {})
    setup_report()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end
  return true
end

local timer = vim.uv.new_timer()
timer:start(1500, 1500, vim.schedule_wrap(function()
  if report and vim.api.nvim_buf_get_name(0) == report and not vim.bo.modified then
    refresh()
  end
end))
vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function() timer:stop(); timer:close() end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local result = vim.fn.system({ "tmux", "set-option", "-p", "-t", vim.env.TMUX_PANE,
      "@research_leader_socket", vim.v.servername })
    if vim.v.shell_error ~= 0 then error(result) end
  end,
})
