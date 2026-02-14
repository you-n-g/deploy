--[[
create a shortcuts like <localleader>c to send the select content or current line to tmux session.
try to find if we have a window named gemini in current session, if so, send the content to gemini.
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

local function get_ai_window(session)
  if not session then return nil end
  local script = vim.fn.expand("~/deploy/configs/tmux/ai/get_ai_window.sh")
  local window = vim.fn.system(script .. " " .. session)
  if vim.v.shell_error ~= 0 then return nil end
  window = trim(window)
  return window ~= "" and window or nil
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

local function get_target_tmux()
  local current_session = get_current_tmux_session()
  local target_session = nil
  local target_window = nil

  local ai_window = get_ai_window(current_session)
  if current_session and ai_window then
    target_session = current_session
    target_window = ai_window
  else
    local input = vim.fn.input("Target tmux session (session.window): ")
    if input == "" then
      print(" Canceled")
      return nil, nil
    end

    -- Support session.window format
    local s, w = string.match(input, "([^%.]+)%.?(.*)")
    if s then
      target_session = s
      target_window = w
    else
      target_session = input
    end
  end
  return target_session, target_window
end


local function format_gemini_prompt(content)
  local relative_path = get_relative_path()
  return string.format(
    "We are edit the file @%s\nYou are focusing the following block\n```\n%s\n```",
    relative_path,
    content
  )
end

function M.send_path_to_gemini()
  local relative_path = get_relative_path()
  local target_session, target_window = get_target_tmux()
  if target_session then
    tmux.send_to_tmux("@" .. relative_path, target_session, target_window)
  end
end

function M.send_to_gemini(raw, post_action)
  if raw == nil then raw = true end
  local content = get_current_or_visual_content()

  local final_content = raw and content or format_gemini_prompt(content)
  local target_session, target_window = get_target_tmux()

  if target_session then
    tmux.send_to_tmux(final_content, target_session, target_window, post_action)
  end
end

function M.send_to_last_window(raw, post_action)
  if raw == nil then raw = true end
  local content = get_current_or_visual_content()

  local final_content = raw and content or format_gemini_prompt(content)
  local session, window = get_last_window_in_current_session()
  if not session then
    print("No tmux session/window found")
    return
  end

  tmux.send_to_tmux(final_content, session, window, post_action)
end

function M.send_literal_to_gemini(content, post_action)
  local target_session, target_window = get_target_tmux()
  if target_session then
    tmux.send_to_tmux(content, target_session, target_window, post_action)
  end
end


function M.setup()
  vim.keymap.set({ "n", "v" }, "<Localleader>c", function() end, { desc = "Send to Gemini/Tmux" })
  -- when it contains chinese, "<Localleader>cc" does not work. But  "<Localleader>ce" works
  vim.keymap.set({ "n", "v" }, "<Localleader>cc", function() M.send_to_gemini(true) end, { desc = "Send to Gemini/Tmux (Raw)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cC", function() M.send_to_gemini(true, "enter") end, { desc = "Send to Gemini/Tmux (Raw, no switch)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>ce", function() M.send_to_gemini(false) end, { desc = "Send to Gemini/Tmux (edit with Context)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cp", function() M.send_path_to_gemini() end, { desc = "Send Path to Gemini/Tmux" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cl", function() M.send_to_last_window(true) end, { desc = "Send to last tmux window in current session (Raw, line/visual)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cL", function() M.send_to_last_window(true, "enter") end, { desc = "Send to last tmux window (Raw, no switch)" })
  -- NOTE: this does not work in navigate-note, because the number leading command is defined by other shortcut.
  vim.keymap.set({ "n" }, "<Localleader>ch", function()
    local count = vim.v.count1
    vim.cmd("r !gemini-hist -n " .. count)
  end, { desc = "Insert last n gemini history below" })
  vim.keymap.set({ "n" }, "<Localleader>cH", ":r !gemini-hist<CR>", { desc = "Insert all gemini history below" })

  for i = 1, 4 do
    vim.keymap.set({ "n", "v" }, "<Localleader>c" .. i, function() M.send_literal_to_gemini(tostring(i), "enter") end, { desc = "Send " .. i .. " to Gemini" })
  end
end

M.setup()

return M
