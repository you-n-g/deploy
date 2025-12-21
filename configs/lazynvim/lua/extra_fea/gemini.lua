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

local function has_gemini_window(session)
  if not session then return false end
  local windows = vim.fn.system("tmux list-windows -t " .. session .. " -F '#{window_name}'")
  if vim.v.shell_error ~= 0 then return false end
  for w in string.gmatch(windows, "[^\r\n]+") do
    if w == "gemini" then
      return true
    end
  end
  return false
end

local function format_gemini_prompt(content)
  local file_path = vim.fn.expand("%:p")
  local project_root = vim.fn.getcwd()
  -- Get relative path by removing project root + trailing slash
  local relative_path = file_path:sub(#project_root + 2)
  if relative_path == "" then relative_path = file_path end

  return string.format(
    "We are edit the file @%s\nYou are focusing the following block\n```\n%s\n```",
    relative_path,
    content
  )
end

function M.send_to_gemini(raw)
  if raw == nil then raw = true end
  local mode = vim.api.nvim_get_mode().mode
  local content
  if mode == "v" or mode == "V" or mode == "\22" then
    content = utils.get_visual_selection()
    -- Exit visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  else
    content = vim.api.nvim_get_current_line()
  end

  local final_content = raw and content or format_gemini_prompt(content)

  local current_session = get_current_tmux_session()
  local target_session = nil
  local target_window = nil

  if current_session and has_gemini_window(current_session) then
    target_session = current_session
    target_window = "gemini"
  else
    local input = vim.fn.input("Target tmux session (session.window): ")
    if input == "" then
      print(" Canceled")
      return
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

  tmux.send_to_tmux(final_content, target_session, target_window)
end

function M.setup()
  vim.keymap.set({ "n", "v" }, "<Localleader>c", function() end, { desc = "Send to Gemini/Tmux" })
  vim.keymap.set({ "n", "v" }, "<Localleader>cc", function() M.send_to_gemini(true) end, { desc = "Send to Gemini/Tmux (Raw)" })
  vim.keymap.set({ "n", "v" }, "<Localleader>ce", function() M.send_to_gemini(false) end, { desc = "Send to Gemini/Tmux (Context)" })
end

M.setup()

return M
