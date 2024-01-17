local M = {
  init=false, -- if it is initialized
}
local api = require "chatgpt.api"
local Settings = require "chatgpt.settings"
local utils = require("simplegpt.utils")



local question = "Who are you? Please create a poetry with multiple lines"
local messages = {
  { content = question, role = "user" },
}

Settings.get_settings_panel("chat_completions", require("chatgpt.config").options.openai_params)  -- call to make  Settings.params exists

P(Settings.params)

local params = vim.tbl_extend("keep", { stream = true, messages = messages }, Settings.params)


-- TODO: append these lines to this popup window
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local popup = Popup({
  relative = "editor",
  enter = true,
  focusable = true,
  border = {
    style = "rounded",
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

-- set content
-- vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { "Hello World" })

local function should_stop()
  if popup.bufnr == nil then
    -- if the window disappeared, then return False
    return true
  end
  return false
end

local function cb(answer, state)
  -- if state is START or CONTINUE, append answer to popup.bufnr.
  -- Please note that a single line may come via multiple times
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
