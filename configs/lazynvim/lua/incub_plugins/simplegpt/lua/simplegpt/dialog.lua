local utils = require("simplegpt.utils")

local M = {}
M.BaseDialog = utils.class("BaseDialog")

function M.BaseDialog:ctor()
  self.all_pops = {}
  -- self.quit_action = "quit"
end

--- register common keys for dialogs
---@param exit_callback 
function M.BaseDialog:register_keys(exit_callback)
  local all_pops = self.all_pops
  -- set keys to escape for all popups
  -- - Quit
  for _, pop in pairs(all_pops) do
    pop:map("n", require"simplegpt.conf".options.dialog.exit_keys, function()

      -- if self.quit_action == "quit" then
      vim.cmd("q")  -- callback may open new windows. So we quit the windows before callback
      -- end

      if exit_callback ~= nil then
        exit_callback()
      end
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
    pop:map("n", { "<tab>" }, _closure_func(i, 1), { noremap = true })
    pop:map("n", { "<S-Tab>" }, _closure_func(i, -1), { noremap = true })
  end
end


local api = require("chatgpt.api")
local Settings = require("chatgpt.settings")

-- The dialog that are able to get response to a specific PopUps
M.ChatDialog = utils.class("ChatDialog", M.BaseDialog)

function M.ChatDialog:ctor()
  M.ChatDialog.super.ctor(self)
  self.answer_popup = nil  -- the popup to display the answer
  self.full_answer = {}
  -- self.quit_action = "hide"
end

function M.ChatDialog:call(question)
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

    if popup.border.winid ~= nil then
      self.popup.border:set_text("top", "State: " .. state, "center")
      self.popup:update_layout()
    end

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

      self.full_answer = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    end
  end

  api.chat_completions(params, cb, should_stop)
end


return M
