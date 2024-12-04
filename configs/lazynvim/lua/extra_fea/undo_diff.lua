--[[
This is a new vim plugin to get a diff view of an undo action.

For a buffer, popup with a diff view in two popup windows.
- on the left is the version after you press undo
- on the right is the current version (it should be the current buffer)

<leader>gu to open the plugin.
]]

local keymaps = {
  exit_keys = "q",
  cycle_next = "<Tab>",
  cycle_prev = "<S-Tab>",
}

local M = {}
local utils = require("simplegpt.utils")
local Popup = require("nui.popup")
local Layout = require("nui.layout")

M.DiffPopup = utils.class("DiffPopup")

function M.DiffPopup:ctor(...)
  self.orig_popup = nil -- the answer content
  self.undo_popup = nil -- the original content
  self.nui_obj = nil -- the nui object
  self.all_pops = {} -- store all popups for easy access
end

function M.DiffPopup:quit()
  -- Quit the dialog window
  -- vim.cmd("q")
  self.nui_obj:unmount()
  -- self.nui_obj:hide()
end

function M.DiffPopup:build(context)
  -- answer prompt
  local orig_popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = { top = "Current Version" },
    },
    bufnr = context.current_bufnr,
  })
  self.orig_popup = orig_popup

  -- question prompt
  local undo_popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = { top = "Undo Version" },
    },
  })
  self.undo_popup = undo_popup

  local boxes = {}
  for _, p in ipairs({ undo_popup, orig_popup }) do
    table.insert(boxes, Layout.Box(p, { ["size"] = "50%" }))
    table.insert(self.all_pops, p)
  end

  local conf_size = require("simplegpt.conf").options.ui.layout.size
  local layout = Layout({
    relative = "editor",
    position = "50%",
    size = {
      width = conf_size.width,
      height = conf_size.height,
    },
  }, Layout.Box(boxes, { dir = "row" }))
  layout:mount()
  self.nui_obj = layout

  -- unmount component when cursor leaves buffer
  self:register_keys()

  -- change settings based on context
  if context ~= nil then
    for _, p in ipairs(self.all_pops) do
      vim.api.nvim_buf_set_option(p.bufnr, "filetype", vim.bo[context.current_bufnr].filetype)
    end

    -- Set the content for the original popup (undo version)
    vim.api.nvim_buf_set_lines(self.undo_popup.bufnr, 0, -1, false, vim.split(context.undo_content, "\n"))
    self:_turn_on_diff()
    vim.api.nvim_set_current_win(self.orig_popup.winid)
  end
end

function M.DiffPopup:register_keys()
  local all_pops = self.all_pops
  -- set keys to escape for all popups
  -- - Quit
  for _, pop in ipairs(all_pops) do
    pop:map("n", keymaps.exit_keys, function()
      self:quit() -- callback may open new windows. So we quit the windows before callback
    end, { noremap = true })
  end

  -- - cycle windows
  local _closure_func = function(i, sft)
    return function()
      -- P(i, sft, (i - 1 + sft) % #all_pops + 1,  all_pops[0].winid, all_pops[1].winid)
      vim.api.nvim_set_current_win(all_pops[(i - 1 + sft) % #all_pops + 1].winid)
    end
  end
  for i, pop in ipairs(all_pops) do
    pop:map("n", keymaps.cycle_next, _closure_func(i, 1), { noremap = true })
    pop:map("n", keymaps.cycle_prev, _closure_func(i, -1), { noremap = true })
  end
end

function M.DiffPopup:_turn_on_diff()
  for _, pop in ipairs(self.all_pops) do
    vim.api.nvim_set_current_win(pop.winid)
    vim.api.nvim_command("diffthis")
    vim.o.wrap = true -- make diff more friendly
  end
end

-- return the undo content of current buf
local function get_undo_content()
  local current_bufnr = vim.api.nvim_get_current_buf()
  local content = {}

  -- Save current position
  local saved_pos = vim.api.nvim_win_get_cursor(0)

  -- Perform undo and capture the content
  vim.cmd("silent undo")
  content = vim.api.nvim_buf_get_lines(current_bufnr, 0, -1, false)

  -- Redo to revert the undo for the user
  vim.cmd("silent redo")

  -- Restore cursor position
  vim.api.nvim_win_set_cursor(0, saved_pos)

  return table.concat(content, "\n")
end

-- Assuming `context` is available or needs to be passed in some way
local function open_diff_popup()
  -- Create a context object with necessary data
  local context = {
    filetype = vim.bo.filetype, -- Get filetype from the original buffer
    undo_content = get_undo_content(), -- Example content
    current_bufnr = vim.api.nvim_get_current_buf(), --
  }

  -- Create an instance of DiffPopup and call build with context
  local diff_popup = M.DiffPopup()
  diff_popup:build(context)
end

-- Register keymaps for the popups
vim.keymap.set("n", "<leader>gu", open_diff_popup, { noremap = true, silent = true, desc = "Open undo diff popup" })

return M
