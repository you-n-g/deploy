local M = {}
local utils = require("simplegpt.utils")
local dialog = require("simplegpt.dialog")
local Popup = require("nui.popup")
-- local event = require("nui.utils.autocmd").event
local Layout = require("nui.layout")

M.DiffPopup = utils.class("Popup", dialog.ChatDialog)


function M.DiffPopup:build()

  -- answer prompt
  local a_popup = Popup({
    -- relative = "editor",
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {top = "Response"},
    },
    -- size = "48%",
  })
  self.popup = a_popup

  -- question prompt
  local orig_popup = Popup({
    -- relative = "editor",
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {top = "Origin"},
    },
    -- size = "48%",
  })
  local boxes = {}
  for _, p in ipairs({orig_popup, a_popup}) do
    table.insert(boxes, Layout.Box(p, { ["size"] = "50%" }))
    table.insert(self.all_pops, p)
  end

  local layout = Layout(
    {
      relative = "editor",
      position = "50%",
      size = {
        width = "90%",
        height = "90%",
      },
    },
    Layout.Box(boxes, { dir = "row" })
  )
  -- mount/open the component
  layout:mount()

  -- unmount component when cursor leaves buffer
  -- TODO: I just want to hide the layout for future resuming
  -- vim.tbl_extend("force", self.all_pops)
  self:register_keys()
end

-- local dp = M.DiffPopup()
-- dp:build()

return M
