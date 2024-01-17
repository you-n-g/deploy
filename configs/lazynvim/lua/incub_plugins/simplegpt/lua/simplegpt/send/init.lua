local M = {
  init = false, -- if it is initialized
}

-- NOTE: we have to initial ChatGPT.nvim at least once to make the settings effective
local Settings = require("chatgpt.settings")
if not M.init then
  Settings.get_settings_panel("chat_completions", require("chatgpt.config").options.openai_params) -- call to make  Settings.params exists
  M.init = true
end

local chat = require("simplegpt.send.chat")
local pop = require("simplegpt.send.popup")
-- local pop = {}

M = vim.tbl_extend("keep", M, chat, pop)

return M
