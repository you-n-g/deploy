--[[
<localleader>c<what><where>: send <what> to <where> (a tmux AI pane).
  what:  r  raw current line / visual selection
         e  explain: the block with its @file (the "focus" template)
         E  the block with a template picked from a list
         p  @path of this file
         t  a request to capture this editor's tmux pane
  where: a  the AI pane of this session (picked when there are several; asks for
            a target when there is none)
         l  the AI pane visited last, in any session
         n  the nearest AI pane: in this window, else the session window
            closest by index
         f  the floating AI pane of this window, created (and waited for)
            when there is none
  A lowercase <where> pastes and switches there; uppercase pastes, presses
  Enter and stays here. E.g. \cel sends the block to the last AI pane.
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

local function get_ai_pane_attributes(session)
  local attrs = {}
  local cmd = "tmux list-panes -s -t "
    .. vim.fn.shellescape(session)
    .. " -F "
    .. vim.fn.shellescape("#{session_name}.#{window_index}.#{pane_index}\t#{@ai_agent_attribute}")
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return attrs
  end

  for line in output:gmatch("[^\n]+") do
    local target, attr = line:match("^([^\t]+)\t(.*)$")
    if target and attr and attr ~= "" and attrs[target] == nil then
      attrs[target] = attr
    end
  end
  return attrs
end

local function format_ai_pane_choice(pane, attrs)
  local target = pane:match("^([^%s]+)")
  local attr = target and attrs[target] or nil
  if attr and attr ~= "" then
    return pane .. " · " .. attr
  end
  return pane
end

local function parse_ai_pane_choice(choice)
  local target = choice and choice:match("^([^%s]+)") or nil
  if not target then
    return nil, nil, nil
  end

  return target:match("^([^%.]+)%.([^%.]+)%.([^%.]+)$")
end

local function get_ai_pane(session, callback)
  if not session then return callback(nil) end
  local script = vim.fn.expand("~/deploy/configs/tmux/ai/get_ai_pane.sh")
  local output = vim.fn.system(vim.fn.shellescape(script) .. " --include-orchestrator -a " .. vim.fn.shellescape(session))
  if vim.v.shell_error ~= 0 then return callback(nil) end

  local attrs = get_ai_pane_attributes(session)
  local panes = {}
  for line in output:gmatch("[^\n]+") do
    local pane = trim(line)
    if pane ~= "" then table.insert(panes, format_ai_pane_choice(pane, attrs)) end
  end

  if #panes == 0 then
    callback(nil)
  elseif #panes == 1 then
    callback(parse_ai_pane_choice(panes[1]))
  else
    vim.schedule(function()
      vim.ui.select(panes, { prompt = "Select AI pane:" }, function(choice)
        if not choice then return end
        callback(parse_ai_pane_choice(choice))
      end)
    end)
  end
end

local function get_relative_path()
  local file_path = vim.fs.normalize(vim.fn.expand("%:p"))
  local project_root = vim.fs.normalize(vim.fn.getcwd())
  local project_prefix = project_root .. "/"

  if file_path:sub(1, #project_prefix) == project_prefix then
    return file_path:sub(#project_prefix + 1)
  end

  return file_path
end

-- The AI pane the user most recently looked at, anywhere.
--
-- Not tmux's own "{last}": as a pane target that means the previous pane within
-- the current window, so once this window has a split next to it, {last} resolves
-- to the neighbour and never to the pane the user actually came from. The real
-- answer is the @last_visit stamps, which is what last_ai_pane.sh reads -- the
-- same script behind the prefix M-l jump, so both land on the same pane.
local function get_last_visited_ai_pane()
  local cmd = { vim.fn.expand("~/deploy/configs/tmux/ai/last_ai_pane.sh") }
  local self_pane = vim.env.TMUX_PANE
  if self_pane and self_pane ~= "" then
    -- Exclude this editor's own pane, not the client's current pane: they differ
    -- whenever the send is triggered from a pane that is not the active one.
    table.insert(cmd, "--exclude")
    table.insert(cmd, self_pane)
  end

  local target = trim(vim.fn.system(cmd))
  if vim.v.shell_error ~= 0 or target == "" then
    return nil, nil, nil
  end

  -- "session:window.pane"; a tmux session name cannot contain ":".
  return target:match("^([^:]+):([^%.]+)%.(.+)$")
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

  get_ai_pane(current_session, function(ai_session, ai_window, ai_pane)
    if ai_session and ai_window and ai_pane then
      callback(ai_session, ai_window, ai_pane)
    else
      local input = vim.fn.input("Target tmux session (session.window[.pane]): ")
      if input == "" then
        print(" Canceled")
        return
      end

      -- Support session.window and session.window.pane format
      local s, w, p = string.match(input, "([^%.]+)%.?([^%.]*)%.?(.*)")
      if s then
        callback(s, w, p)
      else
        callback(input, nil)
      end
    end
  end)
end


local templates = {
  edit = function(content)
    local relative_path = get_relative_path()
    return string.format(
      "We are edit the file @%s\nYou are focusing the following block\n````\n%s\n````",
      relative_path,
      content
    )
  end,
  focus = function(content)
    local relative_path = get_relative_path()
    return string.format(
      "Please pay attention to @%s, specifically this block:\n````\n%s\n````",
      relative_path,
      content
    )
  end,
}

local function pick_template(callback)
  local names = {}
  for k in pairs(templates) do table.insert(names, k) end
  table.sort(names)
  if #names == 0 then
    callback(nil)
  elseif #names == 1 then
    callback(templates[names[1]])
  else
    vim.schedule(function()
      vim.ui.select(names, { prompt = "Select template:" }, function(choice)
        if not choice then callback(nil); return end
        callback(templates[choice])
      end)
    end)
  end
end

local contents = {
  r = {
    group = "raw：当前行/选中原文",
    short = "raw",
    get = function(callback) callback(get_current_or_visual_content()) end,
  },
  e = {
    group = "explain：@文件 + 代码块",
    short = "explain",
    get = function(callback) callback(templates.focus(get_current_or_visual_content())) end,
  },
  E = {
    group = "挑模板：代码块套模板",
    short = "模板",
    get = function(callback)
      local content = get_current_or_visual_content()
      pick_template(function(fn)
        if fn then callback(fn(content)) end
      end)
    end,
  },
  p = {
    group = "path：当前文件 @路径",
    short = "@path",
    get = function(callback) callback("@" .. get_relative_path()) end,
  },
  t = {
    group = "tmux：请 AI capture 本 pane",
    short = "capture 本 pane",
    get = function(callback)
      local tmux_target = get_current_tmux_target_path()
      if not tmux_target then
        print("No current tmux target found")
        return
      end
      callback(string.format("请capture我的Tmux的这个pane[%s]的内容", tmux_target))
    end,
  },
}

local destinations = {
  a = { desc = "本 session 的 AI", resolve = get_target_tmux },
  l = {
    desc = "最近访问的 AI",
    resolve = function(callback)
      local session, window, pane = get_last_visited_ai_pane()
      if not session then
        print("No last visited AI pane found")
        return
      end
      callback(session, window, pane)
    end,
  },
  n = {
    desc = "最近的 AI（本窗口优先，其次编号最近的窗口）",
    resolve = function(callback)
      local host = vim.env.TMUX_PANE
      if not host or host == "" then
        print("Not inside a tmux pane")
        return
      end
      local target = trim(vim.fn.system({ vim.fn.expand("~/deploy/configs/tmux/ai/nearest_ai_pane.sh"), host }))
      if vim.v.shell_error ~= 0 or target == "" then
        print("No AI pane in this session")
        return
      end
      callback(target:match("^([^:]+):([^%.]+)%.(.+)$"))
    end,
  },
  f = {
    desc = "本窗口的浮动 AI（没有就新建）",
    resolve = function(callback)
      local host = vim.env.TMUX_PANE
      if not host or host == "" then
        print("Not inside a tmux pane")
        return
      end
      -- Async: creating the pane waits seconds for the agent to start.
      local script = vim.fn.expand("~/deploy/configs/tmux/ai/ensure_float_ai_pane.sh")
      vim.system({ script, host }, { text = true }, function(res)
        vim.schedule(function()
          if res.code ~= 0 then
            vim.notify("Floating AI pane failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
            return
          end
          local target = vim.trim(vim.fn.system({ "tmux", "display-message", "-p", "-t", vim.trim(res.stdout), "#S\t#I\t#P" }))
          callback(target:match("^([^\t]+)\t([^\t]+)\t(.+)$"))
        end)
      end)
    end,
  },
}

-- The content is read first, while a visual selection is still active; the
-- destination may then prompt or pick asynchronously.
function M.send(what, where, post_action)
  contents[what].get(function(content)
    destinations[where].resolve(function(session, window, pane)
      tmux.send_to_tmux(content, session, window, pane, post_action)
    end)
  end)
end

function M.send_literal_to_ai(content, post_action)
  get_target_tmux(function(target_session, target_window, target_pane)
    tmux.send_to_tmux(content, target_session, target_window, target_pane, post_action)
  end)
end


function M.setup()
  vim.keymap.set({ "n", "v" }, "<Localleader>c<Localleader>", function() M.send_literal_to_ai("", "enter") end, { desc = "给本 session 的 AI 发回车" })
  -- <Localleader>c<what><where>, see the header. Uppercase <where> submits.
  -- Name the \c<what> groups for which-key, which otherwise only shows
  -- "+4 keymaps" there.
  local groups = { { "<Localleader>c", group = "发送到 AI", mode = { "n", "v" } } }
  for what, content in pairs(contents) do
    table.insert(groups, { "<Localleader>c" .. what, group = content.group, mode = { "n", "v" } })
    for where, destination in pairs(destinations) do
      local desc = content.short .. " → " .. destination.desc
      vim.keymap.set({ "n", "v" }, "<Localleader>c" .. what .. where, function() M.send(what, where) end, { desc = desc .. "，跳过去" })
      vim.keymap.set({ "n", "v" }, "<Localleader>c" .. what .. where:upper(), function() M.send(what, where, "enter") end, { desc = desc .. "，⏎ 提交，留在这里" })
    end
  end
  require("which-key").add(groups)
  -- Reads the prompt log the tmux state tracker appends to, not the agents'
  -- own session files: it already has every pane's prompts in one place, in
  -- time order, so there is nothing to merge and nothing to guess about which
  -- session was the "latest" one.
  vim.keymap.set({ "n" }, "<Localleader>ch", function()
    require("fzf-lua").fzf_exec("ai-prompts list", {
      prompt = "AI prompt> ",
      fzf_opts = {
        ["--multi"] = true,
        -- Column 1 is the row id, hidden from the display but still present in
        -- what fzf returns, which is how the selection maps back to a row.
        ["--delimiter"] = "\t",
        ["--with-nth"] = "2..",
        ["--header"] = "Tab: select | Enter: insert below, oldest first | newest at top",
        ["--preview"] = "ai-prompts show {1}",
      },
      winopts = { preview = { hidden = false } },
      actions = {
        ["default"] = function(selected)
          if not selected or not selected[1] then
            return
          end
          local ids = {}
          for _, line in ipairs(selected) do
            local id = line:match("^(%d+)")
            if not id then
              error("ai-prompts: selected row has no id: " .. line)
            end
            table.insert(ids, id)
          end
          local out = vim.fn.systemlist("ai-prompts get " .. table.concat(ids, " "))
          if vim.v.shell_error ~= 0 then
            error("ai-prompts get failed: " .. table.concat(out, "\n"))
          end
          vim.api.nvim_put(out, "l", true, true)
        end,
      },
    })
  end, { desc = "挑历史 prompt 插入到下方（fzf 多选）" })
  vim.keymap.set({ "n" }, "<Localleader>cH", ":r !ai-hist -n ", { desc = "插入全部 AI 历史到下方" })

  for i = 1, 4 do
    vim.keymap.set({ "n", "v" }, "<Localleader>c" .. i, function() M.send_literal_to_ai(tostring(i), "enter") end, { desc = "给本 session 的 AI 发 " .. i .. " 并回车" })
  end
end

M.setup()

return M
