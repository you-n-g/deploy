-- Quiet Markdown view; the leader maintains the file, this pane follows it.
local plugins = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.runtimepath:prepend(plugins .. "tokyonight.nvim")
vim.opt.runtimepath:prepend(plugins .. "render-markdown.nvim")
vim.cmd("filetype plugin on")
vim.cmd("syntax on")
vim.opt.termguicolors = true
vim.cmd.colorscheme("tokyonight-moon")
require("render-markdown").setup({
  render_modes = { "n", "c" },
  anti_conceal = { enabled = false },
  sign = { enabled = false },
  win_options = { concealcursor = { rendered = "nc" } },
})
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.foldenable = false
vim.opt.spell = false
vim.opt.showtabline = 0
vim.opt.modeline = false
vim.opt.swapfile = false
vim.opt.autoread = true
vim.opt.statusline = " 研究计划 / 状态 %= Enter 跳TMA · / 搜索 · :q 关闭 %p%% "

vim.keymap.set("n", "<CR>", function()
  local target = vim.api.nvim_get_current_line():match("tmux://([^%]|%s]+)")
  if target then
    local result = vim.fn.system({ "tmux", "select-window", "-t", target })
    if vim.v.shell_error ~= 0 then error(result) end
    result = vim.fn.system({ "tmux", "select-pane", "-t", target })
    if vim.v.shell_error ~= 0 then error(result) end
  end
end)

function _G.research_leader_open(payload)
  local report = vim.json.decode(payload).report
  if vim.api.nvim_buf_get_name(0) == report then
    local view = vim.fn.winsaveview()
    vim.cmd.checktime()
    vim.fn.winrestview(view)
  else
    vim.api.nvim_cmd({ cmd = "edit", args = { report }, magic = { file = false, bar = false } }, {})
    vim.bo.readonly = true
    vim.bo.modifiable = false
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end
  return true
end

local timer = vim.uv.new_timer()
timer:start(1500, 1500, vim.schedule_wrap(function()
  if vim.api.nvim_buf_get_name(0) ~= "" then
    local view = vim.fn.winsaveview()
    vim.cmd("silent checktime")
    vim.fn.winrestview(view)
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
