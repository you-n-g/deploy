
local api = require "chatgpt.api"
local Settings = require "chatgpt.settings"


local question = "Who are you?"
local messages = {
  { content = question, role = "user" },
}

P(Settings.params)
local params = vim.tbl_extend("keep", { stream = true, messages = messages }, Settings.params)

local function should_stop()
  return false
end

local function cb(answer, state)
  P(answer, state)
end


-- TODO: append these lines to this popup window
-- local Popup = require("nui.popup")
-- local event = require("nui.utils.autocmd").event
--
-- local popup = Popup({
--   enter = true,
--   focusable = true,
--   border = {
--     style = "rounded",
--   },
--   position = "50%",
--   size = {
--     width = "80%",
--     height = "60%",
--   },
-- })
--
-- -- mount/open the component
-- popup:mount()
--
-- -- unmount component when cursor leaves buffer
-- popup:on(event.BufLeave, function()
--   popup:unmount()
-- end)
--
-- -- set content
-- vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { "Hello World" })

api.chat_completions(params, cb, should_stop)


