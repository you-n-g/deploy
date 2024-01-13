
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

api.chat_completions(params, cb, should_stop)


