local M = {
  init = false, -- if it is initialized
}
local api = require("chatgpt.api")
local Settings = require("chatgpt.settings")
local utils = require("simplegpt.utils")
local dialog = require("simplegpt.dialog")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

M.Popup = utils.class("Popup", dialog.BaseDialog)

function M.Popup:ctor()
  self.super:ctor()
  self.popup = nil
end

function M.Popup:build()
  local popup = Popup({
    relative = "editor",
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {top = "Response"},
    },
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
  })

  -- mount/open the component
  popup:mount()

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)
  self.popup = popup
  -- vim.tbl_extend("force", self.all_pops)
  table.insert(self.all_pops, popup)
  self:register_keys()
end

function M.Popup:call(question)
  local messages = {
    { content = question, role = "user" },
  }

  local params = vim.tbl_extend("keep", { stream = true, messages = messages }, Settings.params)
  local popup = self.popup -- add it to namespace to support should_stop & cb

  local function should_stop()
    if popup.bufnr == nil then
      -- if the window disappeared, then return False
      return true
    end
    return false
  end

  local function cb(answer, state)
    -- TODO: add processing to title
    -- if state is START or CONTINUE, append answer to popup.bufnr.
    -- Please note that a single line may come via multiple times

    -- set self.popup's title to "state"
    -- self.popup.border.text = {top = state}
    self.popup.border:set_text("top", "State: " .. state, "center")
    self.popup:update_layout()
    if state == "START" or state == "CONTINUE" then
      local line_count = vim.api.nvim_buf_line_count(popup.bufnr)
      local last_line = vim.api.nvim_buf_get_lines(popup.bufnr, line_count - 1, line_count, false)[1]
      -- TODO: if answer contains "\n" or "\r", break it and creat multipe
      local lines = vim.split(answer, "\n")
      for i, line in ipairs(lines) do
        if i == 1 then
          -- append the first line of the answer to the last line in the buffer
          local new_line = last_line .. line
          vim.api.nvim_buf_set_lines(popup.bufnr, line_count - 1, line_count, false, { new_line })
        else
          -- append the remaining lines of the answer as new lines in the buffer
          vim.api.nvim_buf_set_lines(popup.bufnr, -1, -1, false, { line })
        end
      end
    end
  end

  api.chat_completions(params, cb, should_stop)
end

function M.get_response()
  local rqa = require"simplegpt.tpl".RegQAUI()
  rqa:build(function (question)
    local pp = M.Popup()
    -- set the filetype of pp  to mark down to enable highlight
    pp:build()
    -- TODO: copy code with regex
    vim.api.nvim_buf_set_option(pp.popup.bufnr, 'filetype', 'markdown')
    pp:call(question)
  end)
end
return M
