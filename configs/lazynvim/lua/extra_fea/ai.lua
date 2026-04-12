--[[
create a shortcuts like <localleader>c to send the select content or current line to tmux session.
try to find if we have an AI window in current session, if so, send the content to AI.
otherwise, wait input for user to input the session name..
--]]
local M = {}
local utils = require("navigate-note.utils")
local tmux = require("navigate-note.tmux")

local function trim(s)
  return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

local function get_current_tmux_session()
  local session = vim.fn.system("tmux display-message -p '#S'")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return trim(session)
end

local function get_current_tmux_target_path()
  local target = vim.fn.system("tmux display-message -p '#S:#I.#P'")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  target = trim(target)
  return target ~= "" and target or nil
end

local function get_ai_window(session, callback)
  if not session then return callback(nil) end
  local script = vim.fn.expand("~/deploy/configs/tmux/ai/get_ai_window.sh")
  local output = vim.fn.system(script .. " -a " .. session)
  if vim.v.shell_error ~= 0 then return callback(nil) end

  local windows = {}
  for line in output:gmatch("[^\n]+") do
    local w = trim(line)
    if w ~= "" then table.insert(windows, w) end
  end

  if #windows == 0 then
    callback(nil)
  elseif #windows == 1 then
    -- "code:3 (claude)" → extract window index "3"
    local idx = windows[1]:match("^[^:]+:(%d+)")
    callback(idx)
  else
    vim.schedule(function()
      vim.ui.select(windows, { prompt = "Select AI window:" }, function(choice)
        if not choice then return end
        local idx = choice:match("^[^:]+:(%d+)")
        callback(idx)
      end)
    end)
  end
end

local function get_relative_path()
  local file_path = vim.fn.expand("%:p")
  local project_root = vim.fn.getcwd()
  -- Get relative path by removing project root + trailing slash
  local relative_path = file_path:sub(#project_root + 2)
  if relative_path == "" then relative_path = file_path end
  return relative_path
end

local function get_last_window_in_current_session()
  -- current session name
  local session = vim.fn.system("tmux display-message -p '#S'")
  if vim.v.shell_error ~= 0 then
    return nil, nil
  end
  session = trim(session)
  if session == "" then
    return nil, nil
  end

  -- last (most recently used) window index in current session
  local window = vim.fn.system("tmux list-windows -t " .. session .. " -F '#{window_index}' -f '#{window_last_flag}'")
  if vim.v.shell_error ~= 0 then
    return session, nil
  end
  window = trim(window)
  if window == "" then
    return session, nil
  end

  return session, window
end

local function get_current_or_visual_content()
  local mode = vim.api.nvim_get_mode().mode
  local content
  if mode == "v" or mode == "V" or mode == "\22" then
    content = utils.get_visual_selection()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  else
    content = vim.fn.getline(".") -- vim.api.nvim_get_current_line() does not work with Chinese characters
  end
  return content
end

local function get_target_tmux(callback)
  local current_session = get_current_tmux_session()

  get_ai_window(current_session, function(ai_window)
    if current_session and ai_window then
      callback(current_session, ai_window)
    else
      local input = vim.fn.input("Target tmux session (session.window): ")
      if input == "" then
        print(" Canceled")
        return
      end

      -- Support session.window format
      local s, w = string.match(input, "([^%.]+)%.?(.*)")
      if s then
        callback(s, w)
      else
        callback(input, nil)
      end
    end
  end)
end


local function format_ai_prompt(content)
  local relative_path = get_relative_path()
  return string.format(
    "We are edit the file @%s\nYou are focusing the following block\n```\n%s\n```",
    relative_path,
    content
  )
end

function M.send_path_to_ai()
  local relative_path = get_relative_path()
  get_target_tmux(function(target_session, target_window)
    tmux.send_to_tmux("@" .. relative_path, target_session, target_window)
  end)
end

function M.send_current_tmux_target_to_ai()
  local tmux_target = get_current_tmux_target_path()
  if not tmux_target then
    print("No current tmux target found")
    return
  end

  get_target_tmux(function(target_session, target_window)
    tmux.send_to_tmux(string.format("请capture我的Tmux的这个pane[%s]的内容", tmux_target), target_session, target_window)
  end)
end

function M.send_to_ai(raw, post_action)
  if raw == nil then raw = true end
  local final_content
  if type(raw) == "string" then
    final_content = raw
  else
    local content = get_current_or_visual_content()
    final_content = raw and content or format_ai_prompt(content)
  end

  get_target_tmux(function(target_session, target_window)
    tmux.send_to_tmux(final_content, target_session, target_window, nil, post_action)
  end)
end

function M.send_to_last_window(raw, post_action)
  if raw == nil then raw = true end
  local content = get_current_or_visual_content()

  local final_content = raw and content or format_ai_prompt(content)
  local session, window = get_last_window_in_current_session()
  if not session then
    print("No tmux session/window found")
    return
  end

  tmux.send_to_tmux(final_content, session, window, nil, post_action)
end

function M.send_literal_to_ai(content, post_action)
  get_target_tmux(function(target_session, target_window)
    tmux.send_to_tmux(content, target_session, target_window, nil, post_action)
  end)
end


function M.setup()
  vim.keymap.set({ "n", "v" }, "<Localleader>c", function() end, { desc = "Send to AI/Tmux" })
  -- when it contains chinese, "<Localleader>cc" does not work. But  "<Localleader>ce" works
  vim.keymap.set({ "n", "v" }, "<Localleader>c<Localleader>", function() M.send_to_ai("", "enter") end, { desc = "Send Enter to AI/Tmux" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cc", function() M.send_to_ai(true) end, { desc = "Send to AI/Tmux (Raw)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cC", function() M.send_to_ai(true, "enter") end, { desc = "Send to AI/Tmux (Raw, no switch)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>ce", function() M.send_to_ai(false) end, { desc = "Send to AI/Tmux (edit with Context)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cp", function() M.send_path_to_ai() end, { desc = "Send Path to AI/Tmux" })
  vim.keymap.set({ "n", "v" }, "<Localleader>ct", function() M.send_current_tmux_target_to_ai() end, { desc = "Send current tmux target to AI/Tmux" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cl", function() M.send_to_last_window(true) end, { desc = "Send to last tmux window in current session (Raw, line/visual)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cL", function() M.send_to_last_window(true, "enter") end, { desc = "Send to last tmux window (Raw, no switch)" })
  -- NOTE: this does not work in navigate-note, because the number leading command is defined by other shortcut.
  vim.keymap.set({ "n" }, "<Localleader>ch", function()
    local count = vim.v.count1
    vim.cmd("r !ai-hist -n " .. count)
  end, { desc = "Insert last n AI history below" })
  vim.keymap.set({ "n" }, "<Localleader>cH", ":r !ai-hist -n ", { desc = "Insert all AI history below" })

  for i = 1, 4 do
    vim.keymap.set({ "n", "v" }, "<Localleader>c" .. i, function() M.send_literal_to_ai(tostring(i), "enter") end, { desc = "Send " .. i .. " to AI" })
  end
end

M.setup()

return M
