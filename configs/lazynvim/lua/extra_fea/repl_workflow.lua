--[[
Difference from normal repl
- It will base on your current script
  - when run whole scripts, run the correct runner
  - open the correct interpreter
  - block sending: e.g. %paste for Python,  # %% for jupyter
- more custmization with strong assumption
  - command prefix dotenv.
  - run a specific function of the script (assumption about fire/typer)
]]
-- it is based on toggleterm.nvim and vim-slime.
local M = {}

class = require("simplegpt.utils").class

-- get current buffer name
function update_toggleterm_last_id()
  local name = vim.api.nvim_buf_get_name(0)
  -- if name ends with pattern "#\d", then set \d to variable i
  if string.match(name, "#%d$") then
    vim.g.toggleterm_last_id = tonumber(string.match(name, "#(%d)$"))
  end
end


function M.get_toggleterm_last_id()
  return vim.g.toggleterm_last_id or 1
end


vim.api.nvim_exec(
  [[
augroup auto_toggleterm_channel
  autocmd!
  autocmd BufEnter,WinEnter,TermOpen  * lua update_toggleterm_last_id()
augroup END]],
  false
)

local function sendContent()
  -- if filetype is python
  if vim.bo.filetype == "python" then
    -- FIXME: this still does not work.  Windows will raise error if you send line break
    vim.api.nvim_feedkeys('"+y', "n", false)
    -- vim.api.nvim_feedkeys([[:SlimeSend0 "%paste"]] .. "\n", "n", false)
    -- vim.api.nvim_feedkeys([[:SlimeSend0 "\x0d"]] .. "\n", "n", false)
    -- vim.cmd([[TermExec cmd="\%paste"]]) -- NOTE: this may affect the final results
    vim.fn.chansend(vim.g.slime_last_toggleterm_channel, "%paste")

    -- local cmd = "call chansend(" .. vim.g.slime_last_toggleterm_channel .. ', "\\<cr>")'
    -- print(cmd)
    -- vim.cmd("call chansend(" .. vim.g.slime_last_toggleterm_channel .. ', "\\<cr>")')
    -- vim.cmd(cmd)
    -- vim.cmd(cmd)
    -- vim.cmd(cmd)
    -- FIXME: the linebreak will work in terminal. but it will not in functions ... Mysterious...
    -- NOTE:: in windows, the \r will not work if we send other things in the same function
    vim.fn.chansend(vim.g.slime_last_toggleterm_channel, "\r")

    -- useing nvim_replace_termcodes does not solve the problem
    -- local enter_key = vim.api.nvim_replace_termcodes('<cr>', true, true, true)
    -- vim.fn.chansend(vim.g.slime_last_toggleterm_channel, enter_key)
    -- send againt still does not work...
    -- print("send againt..")
    -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<c-c><cr>', true, true, true), 'n', false)
    return nil
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode == "n" then
    vim.cmd(string.format([[ToggleTermSendCurrentLine %s]], M.get_toggleterm_last_id()))
  elseif mode == "V" or mode == "v" then
    -- run command ToggleTermSendVisualSelection in visual mode
    vim.api.nvim_feedkeys(
      string.format(":ToggleTermSendVisualSelection %s\n", M.get_toggleterm_last_id()),
      "n",
      true
    )
  end
end

if vim.fn.has("win32") == 1 then
  -- TODO: windows will not send the prefix blanks... It is weird..
  -- https://github.com/akinsho/toggleterm.nvim/issues/243
  vim.keymap.set({ "n", "x", "v" }, "<c-c><c-c>", sendContent, { noremap = true, desc = "send content(win32)" })
  -- otherwise vim-slime will be used
end

-- 下面的代码是基于下面的讨论
-- https://www.reddit.com/r/neovim/comments/nnru7r/how_do_i_get_the_name_of_the_current_function_i/
-- 这个版本还有如下问题
-- - 遇到comments，就直接变成<node source了>
local ts_utils = require("nvim-treesitter.ts_utils")
-- local query = require'vim.treesitter.query'
-- get_node_text 说是新版的得从这里拿，但是这里没找到怎么拿

local function get_current_function_name(find_cls, sep)
  -- default value is false
  find_cls = (find_cls == nil and false) or find_cls
  sep = (sep == nil and "::") or sep

  local current_node = ts_utils.get_node_at_cursor()

  if not current_node then
    return ""
  end

  local expr = current_node

  while expr do
    -- in lua, the definition of function are with type "function"
    if expr:type() == "function_definition" or expr:type() == "function" then
      break
    end
    expr = expr:parent()
  end

  if not expr then
    return ""
  end

  -- TODO: 我觉得这里应该有更方便的获得 node function name的方法
  local name_index = 1
  -- print(expr:child(name_index):type())
  if expr:child(name_index):type() == "(" then
    -- this is for some bash scripts without `function` decoration. So the first word should be function name
    name_index = 0
  end
  -- query.get_node_text
  local func_name = (ts_utils.get_node_text(expr:child(name_index)))[1]
  if not find_cls then
    return func_name
  end

  -- find class name
  while expr do
    -- in lua, the definition of function are with type "function"
    if expr:type() == "class_definition" then
      break
    end
    expr = expr:parent()
  end

  if not expr or expr:type() ~= "class_definition" then
    return func_name
  end

  local cls_name = (ts_utils.get_node_text(expr:child(1)))[1]
  return cls_name .. sep .. func_name
end

M.get_current_function_name = get_current_function_name

-- Configs
M.config = {
  edit_before_send = false,
  -- 
  debug_mode = "",
  load_env = true, -- load_env before.
  doc_test = false,
  abs_path = true, -- should we use absolute path
  -- aider_mode configures the mode for aiding development by altering command behavior.
  -- It can be set to:
  -- "" (empty string) for the default mode,
  -- "/test" to prepend commands with a testing directive,
  -- "/run" to prepend commands with a runtime directive.
  -- The default value is "".
  -- term_mode = "",  -- default mode, can switch between "", "/test" , "/run"
  -- term_modes is a placeholder to switch mode in terminal level
  key_shell = "",  -- key_shell.sh azure|azure_ad|
}

-- Helper function to find the index of a value in a table
function M.find_index(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      return i
    end
  end
  return nil
end

--- Modify the command before sending it out
---@param cmd 
local function edit_before_send(cmd)
  -- modify the M.config based on M.config
  if M.config.load_env then
    cmd = "mydotenv.sh " .. cmd
  end

  -- Get terminal-specific mode if available
  local term_id = M.get_toggleterm_last_id()
  local term_mode = M.config.term_modes and M.config.term_modes[term_id]
  if term_mode and term_mode ~= "" then
    cmd = term_mode .. " " .. cmd
  end

  -- involve human editing
  if M.config.edit_before_send then
    vim.ui.input({ prompt = "Edit before sending", default = cmd }, function(input)
      require("toggleterm").exec(input, M.get_toggleterm_last_id(), 12)
    end)
  else
    require("toggleterm").exec(cmd, M.get_toggleterm_last_id(), 12)
  end
end

vim.keymap.set("n", "<leader>rce", function()
  --  toggle  M.config["edit_before_send"] between true and false
  M.config["edit_before_send"] = not M.config["edit_before_send"]
  P(M.config["edit_before_send"])
end, { desc = "edit before send." })

vim.keymap.set("n", "<leader>rcd", function()
  -- Toggle M.config["debug_mode"] through the modes in mode_l
  local mode_l = {"", "pdb", "dap"}
  local current_mode = M.config["debug_mode"]
  local next_index = ((M.find_index(mode_l, current_mode) or 0) % #mode_l) + 1
  M.config["debug_mode"] = mode_l[next_index]
  P(M.config["debug_mode"])
end, { desc = "Toggle debug mode." })

vim.keymap.set("n", "<leader>rct", function()
  --  toggle  M.config["edit_before_send"] between true and false
  M.config["doc_test"] = not M.config["doc_test"]
  P(M.config["doc_test"])
end, { desc = "Using doctest for testing." })

vim.keymap.set("n", "<leader>rca", function()
  --  toggle  M.config["abs_path"] between true and false
  M.config["abs_path"] = not M.config["abs_path"]
  P(M.config["abs_path"])
end, { desc = "Toggle Absolute Path." })


vim.keymap.set("n", "<leader>rcl", function()
  --  toggle  M.config["edit_before_send"] between true and false
  M.config["load_env"] = not M.config["load_env"]
  P(M.config["load_env"])
end, { desc = "Toggle load env before sending." })

-- Base class and methods

local BaseREPL = class("BaseREPL")

function BaseREPL:run_func()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand(self:get_path_symbol()) .. " " .. get_current_function_name()

  edit_before_send(cmd)
end

function BaseREPL:run_script()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand(self:get_path_symbol())
  edit_before_send(cmd)
end

function BaseREPL:launch_interpreter()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  edit_before_send(self.interpreter)
end

function BaseREPL:test()
  print("No test supported")
end

function BaseREPL:send_code()
  -- send key <c-c><c-c> by default
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-c><c-c>", true, true, true), "n", false)
end

function BaseREPL:get_path_symbol()
  -- send key <c-c><c-c> by default
  if M.config.abs_path then
    return "%:p"
  else
    return "%"
  end
end

function BaseREPL:debug_breakpoint()
  -- get the current line number
  local line_number = vim.fn.line(".")
  -- get the current file path
  local file_path = vim.fn.expand("%:p")
  -- construct the command
  local cmd = string.format("b %s:%d", file_path, line_number)
  -- send the command to the terminal
  require("toggleterm").exec(cmd, M.get_toggleterm_last_id(), 12)
end

function BaseREPL:debug_unt()
  local line_number = vim.fn.line(".")
  -- construct the command
  local cmd = string.format("unt %d", line_number)
  -- send the command to the terminal
  require("toggleterm").exec(cmd, M.get_toggleterm_last_id(), 12)
end

function BaseREPL:debug_explore(var)
  print("No debug_explore supported")
end

function BaseREPL:debug_print()
  -- TODO:
  -- if in visual model, set the selected content to the current word
  -- otherwise set the current word to the content
  local cur_content
  local mode = vim.api.nvim_get_mode().mode
  if mode == "n" then
    -- In normal mode, get the current word under the cursor
    cur_content = vim.fn.expand("<cword>")
  elseif mode == "v" or mode == "V" or mode == "\\<C-v>" then
    cur_content = require("extra_fea.utils").get_visual_selection_content()
  end
  local cmd = string.format("p %s", cur_content)
  require("toggleterm").exec(cmd, M.get_toggleterm_last_id(), 12)
end

function BaseREPL:start_db()
  print("No start ?db supported")
end

-- for all kinds of language

-- - Python
local PythonREPL = class("PythonREPL", BaseREPL)
PythonREPL.interpreter = "python"

function PythonREPL:launch_interpreter()
  edit_before_send("ipython")
end

function get_pytest_doctest_module()
  -- python test doctest module:
  -- - because  --doctest-modules expect  <filepath>::<full_packagename>.<function_name> to specific a function.
  -- - vim can't automatically get it. So we have to set it mannually often.
  -- often used command let b:ptdm="abc"
  -- - let b:ptdm="abc"
  -- - unlet b:ptdm
  local ok, ptdm = pcall(vim.api.nvim_buf_get_var, 0, "ptdm")
  if ok then
    return ptdm
  end
  local st = vim.fn.expand("%:r")
  local t = vim.split(st, "/")

  local module = {}
  local finished = false
  for i = #t, 1, -1 do
    v = t[i]
    if not finished then
      -- module = v .. "." .. module
      table.insert(module, v)
    end
    -- FIXME: qlib is hard code!!!!!
    if v == "qlib" then
      finished = true
    end
  end

  if finished then
    -- reverse t
    for i = 1, #module / 2 do
      local tmp = module[i]
      module[i] = module[#module - i + 1]
      module[#module - i + 1] = tmp
    end
    return table.concat(module, ".")
  else
    return vim.fn.expand("%:t:r")
  end
end

function PythonREPL:test()
  -- nnoremap <silent>  <leader>psT :SlimeSend0 "pytest -s --pdb --disable-warnings --doctest-modules ".expand("%:p")."::".luaeval("get_pytest_doctest_module()").".".luaeval('require("yx/plugs/run_func").get_current_function_name(true)')."\n"<CR>
  local cmd = ""
  if M.config.doc_test then
    cmd = "pytest -s --pdb --disable-warnings --doctest-modules "
      .. vim.fn.expand("%:p")
      .. "::"
      .. get_pytest_doctest_module()
      .. "."
      .. get_current_function_name(true)
  else
    cmd = "pytest -s --pdb --disable-warnings " .. vim.fn.expand("%:p") .. "::" .. get_current_function_name(true)
  end
  local interpret = self:get_interpreter()
  -- interact with user to edit `cmd`
  edit_before_send(interpret .. " -m " .. cmd)
end

function PythonREPL:get_interpreter()
  local cmd = ""
  if M.config.debug_mode == "pdb" then
    cmd = "python -m ipdb -c c "
  elseif M.config.debug_mode == "dap" then
    cmd = "python -m debugpy --listen 0.0.0.0:5678 --wait-for-client "
    -- Start nvim-dap and connect to 127.0.0.1:5678 in 2 seconds using existing config.
    local dap = require('dap')
    if #vim.api.nvim_list_tabpages() == 1 then -- do it only when we have 1 tab.
      vim.defer_fn(function()

        if vim.fn.expand("%") == "" then
          -- If not, open a new tab with an existing buffer that is associated with a file
          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(bufnr) and vim.fn.bufname(bufnr) ~= "" then
              -- If the buffer is not associated with a file, open a new tab without switching to the buffer
              vim.cmd("tab split | b" .. bufnr)
              return
            end
          end
        end
        -- If the current buffer is associated with a file, open a new tab with the current buffer
        vim.cmd("tab split")

        dap.continue()
        -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("3<cr><cr>", true, false, true), "i", false) -- Too fast pressing may result in errors..
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("3", true, false, true), "i", false)
      end, 1000)
    end
  else
    cmd = "python "
  end
  return cmd
end


function PythonREPL:run_script()
  edit_before_send(self:get_interpreter() .. " " .. vim.fn.expand(self:get_path_symbol()))
end

function PythonREPL:run_func()
  local cmd = self:get_interpreter() .. " " .. vim.fn.expand(self:get_path_symbol()) .. " "
  local func_name = get_current_function_name()
  -- NOTE: this is a hack for typer (the design is bad...)
  -- if `import typer` is included in the file, the replace the '_' with '-' in `cmd`
  if vim.fn.search("import typer", "nw") ~= 0 then
    func_name = string.gsub(func_name, "_", "-")
  end
  cmd = cmd .. func_name
  edit_before_send(cmd)
end

function PythonREPL:start_db()
  local cmd = "python -m ipdb"
  cmd = cmd .. " " .. vim.fn.expand(self:get_path_symbol())
  edit_before_send(cmd)
end

function PythonREPL:debug_explore(var)
  local cur_content
  if var == nil then
    local mode = vim.api.nvim_get_mode().mode
    if mode == "n" then
      -- In normal mode, get the current word under the cursor
      cur_content = vim.fn.expand("<cword>")
    elseif mode == "v" or mode == "V" or mode == "\\<C-v>" then
      cur_content = require("extra_fea.utils").get_visual_selection_content()
    end
  else
    cur_content = var
  end
  local cmd = string.format('__import__("objexplore").explore(%s)', cur_content)
  -- send the command to the terminal
  require("toggleterm").exec(cmd, M.get_toggleterm_last_id(), 12)
end

-- - Bash
local BashREPL = class("BashREPL", BaseREPL)
BashREPL.interpreter = "bash"

function BashREPL:launch_interpreter()
  edit_before_send("zsh")
end

-- - Lua
local LuaREPL = class("LuaREPL", BaseREPL)

function LuaREPL:send_code()
  -- TODO:
  -- - Maybe we should add `return` in load; Currently it just simply add return to the last line. Maybe we should use treesitter intead.
  local mode = vim.api.nvim_get_mode().mode
  if mode == "n" then
    -- lua run current line if in normal mode
    local row = vim.fn.getpos(".")[2]
    local lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
    print(load("return " .. lines[1])())
  elseif mode == "v" or mode == "V" or mode == "\\<C-v>" then
    -- https://www.reddit.com/r/neovim/comments/13mfta8/reliably_get_the_visual_selection_range/
    -- We must escape visual mode before make  "<" ">"  take effects
    -- P("before:", vim.api.nvim_get_mode().mode)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
    -- -- Finnaly, I found it will not exit visual mode to make '<'> take effect.
    -- P("end:", vim.api.nvim_get_mode().mode)

    -- P(vim.api.nvim_buf_get_mark(0, "<"), vim.api.nvim_buf_get_mark(0, ">"))
    local code = require("extra_fea.utils").get_visual_selection_content()
    local lines = vim.split(code, "\n")
    lines[#lines] = "return " .. lines[#lines]
    code = table.concat(lines, "\n")
    print(code) -- TODO: remove it
    print(load(code)())
  end
end

function LuaREPL:run_script()
  dofile(vim.fn.expand(self:get_path_symbol()))
end

function M.REPLFactory()
  local ft = vim.bo.filetype
  local repl_map = {
    python = PythonREPL,
    sh = BashREPL,
    bash = BashREPL,
    lua = LuaREPL,
  }
  if repl_map[ft] == nil then
    return BashREPL() -- fall back to BashREPL by default
  end
  return repl_map[ft]()
end

-- General Keymaps

vim.keymap.set("n", "<leader>rs", function()
  M.REPLFactory():run_script()
end, { desc = "Run script" })

vim.keymap.set("n", "<leader>rf", function()
  M.REPLFactory():run_func()
end, { desc = "Run function" })

vim.keymap.set("n", "<leader>rL", function()
  M.REPLFactory():launch_interpreter()
end, { desc = "Launch interpreter" })

vim.keymap.set("n", "<leader>rt", function()
  M.REPLFactory():test()
end, { desc = "Run Test" })

vim.keymap.set("n", "<leader>rdb", function()
  M.REPLFactory():debug_breakpoint()
end, { desc = "Send break point" })

vim.keymap.set("n", "<leader>rdd", function()
  M.REPLFactory():start_db()
end, { desc = "start ?db" })

vim.keymap.set("n", "<leader>rdu", function()
  M.REPLFactory():debug_unt()
end, { desc = "until line" })

vim.keymap.set({ "n", "v" }, "<leader>rdp", function()
  M.REPLFactory():debug_print()
end, { desc = "print variable" })

vim.keymap.set({ "n", "v" }, "<leader>rde", function()
  M.REPLFactory():debug_explore()
end, { desc = "explore object" })

vim.keymap.set("n", "<leader>rdE", function()
  M.REPLFactory():debug_explore("locals()")
end, { desc = "explore locals()" })

-- TODO: `configs/nvim/yx/plugins_conf.vim` for doc test

vim.keymap.set({ "n", "v", "o" }, "<leader>rr", function()
  -- P(vim.api.nvim_get_mode().mode)
  -- local start_pos = vim.api.nvim_buf_get_mark(0, '<')
  -- local end_pos = vim.api.nvim_buf_get_mark(0, '>')
  -- DEBUGGING:
  -- print("start:")
  -- P(start_pos)
  -- print("end:")
  -- P(end_pos)
  M.REPLFactory():send_code()
end, { desc = "Send Code to (R)un" })

-- M.config
-- coroutine may be helpful: https://github.com/stevearc/dressing.nvim/discussions/70

return M
