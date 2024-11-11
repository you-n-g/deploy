-- it is based on toggleterm.nvim and vim-slime.
local M = {}

-- util function
local function class(className, super)
  -- a lua class with initializer
  -- 构建类
  local clazz = { __cname = className, super = super }
  if super then
    -- 设置类的元表，此类中没有的，可以查找父类是否含有
    setmetatable(clazz, { __index = super })
  end
  -- new 方法创建类对象
  clazz.new = function(...)
    -- 构造一个对象
    local instance = {}
    -- 设置对象的元表为当前类，这样，对象就可以调用当前类生命的方法了
    setmetatable(instance, { __index = clazz })
    if clazz.ctor then
      clazz.ctor(instance, ...)
    end
    return instance
  end
  return clazz
end

-- get current buffer name
function update_toggleterm_last_id()
  local name = vim.api.nvim_buf_get_name(0)
  -- if name ends with pattern "#\d", then set \d to variable i
  if string.match(name, "#%d$") then
    vim.g.toggleterm_last_id = string.match(name, "#(%d)$")
  end
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
    vim.cmd(string.format([[ToggleTermSendCurrentLine %s]], vim.g.toggleterm_last_id or ""))
  elseif mode == "V" or mode == "v" then
    -- run command ToggleTermSendVisualSelection in visual mode
    vim.api.nvim_feedkeys(
      string.format(":ToggleTermSendVisualSelection %s\n", vim.g.toggleterm_last_id or ""),
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
local config = {
  edit_before_send = false,
  goto_debug_when_fail = false,
  load_env = true, -- load_env before.
  doc_test = false,
  abs_path = true, -- should we use absolute path
}

--- Modify the command before sending it out
---@param cmd 
local function edit_before_send(cmd)
  -- modify the config based on config
  if config.load_env then
    cmd = "mydotenv.sh " .. cmd
  end

  -- involve human editing
  if config.edit_before_send then
    vim.ui.input({ prompt = "Edit before sending", default = cmd }, function(input)
      require("toggleterm").exec(input, tonumber(vim.g.toggleterm_last_id), 12)
    end)
  else
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
  end
end

vim.keymap.set("n", "<leader>rce", function()
  --  toggle  config["edit_before_send"] between true and false
  config["edit_before_send"] = not config["edit_before_send"]
  P(config["edit_before_send"])
end, { desc = "edit before send." })

vim.keymap.set("n", "<leader>rcd", function()
  --  toggle  config["edit_before_send"] between true and false
  config["goto_debug_when_fail"] = not config["goto_debug_when_fail"]
  P(config["goto_debug_when_fail"])
end, { desc = "go to debug when exception." })

vim.keymap.set("n", "<leader>rct", function()
  --  toggle  config["edit_before_send"] between true and false
  config["doc_test"] = not config["doc_test"]
  P(config["doc_test"])
end, { desc = "Using doctest for testing." })

vim.keymap.set("n", "<leader>rca", function()
  --  toggle  config["edit_before_send"] between true and false
  config["abs_path"] = not config["abs_path"]
  P(config["abs_path"])
end, { desc = "Toggle Absolute Path." })

vim.keymap.set("n", "<leader>rcl", function()
  --  toggle  config["edit_before_send"] between true and false
  config["load_env"] = not config["load_env"]
  P(config["load_env"])
end, { desc = "Toggle load env before sending." })

-- Base class and methods

local BaseREPL = class("BaseREPL")

function BaseREPL:run_func()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand(self:get_path_symbol()) .. " " .. get_current_function_name()
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
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
  print("No interpreter supported...")
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
  if config.abs_path then
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
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
end

function BaseREPL:debug_unt()
  local line_number = vim.fn.line(".")
  -- construct the command
  local cmd = string.format("unt %d", line_number)
  -- send the command to the terminal
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
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
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
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
  if config.doc_test then
    cmd = "pytest -s --pdb --disable-warnings --doctest-modules "
      .. vim.fn.expand("%:p")
      .. "::"
      .. get_pytest_doctest_module()
      .. "."
      .. get_current_function_name(true)
  else
    cmd = "pytest -s --pdb --disable-warnings " .. vim.fn.expand("%:p") .. "::" .. get_current_function_name(true)
  end
  -- interact with user to edit `cmd`
  edit_before_send(cmd)
end

function PythonREPL:get_interpreter()
  local cmd = ""
  if config.goto_debug_when_fail then
    cmd = "python -m ipdb -c c "
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
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
end

-- - Bash
local BashREPL = class("BashREPL", BaseREPL)
BashREPL.interpreter = "bash"

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

local function REPLFactory()
  local ft = vim.bo.filetype
  local repl_map = {
    python = PythonREPL,
    sh = BashREPL,
    bash = BashREPL,
    lua = LuaREPL,
  }
  return repl_map[ft].new()
end

-- General Keymaps

vim.keymap.set("n", "<leader>rs", function()
  REPLFactory():run_script()
end, { desc = "Run script" })

vim.keymap.set("n", "<leader>rf", function()
  REPLFactory():run_func()
end, { desc = "Run function" })

vim.keymap.set("n", "<leader>rL", function()
  REPLFactory():launch_interpreter()
end, { desc = "Launch interpreter" })

vim.keymap.set("n", "<leader>rt", function()
  REPLFactory():test()
end, { desc = "Run Test" })

vim.keymap.set("n", "<leader>rdb", function()
  REPLFactory():debug_breakpoint()
end, { desc = "Send break point" })

vim.keymap.set("n", "<leader>rdd", function()
  REPLFactory():start_db()
end, { desc = "start ?db" })

vim.keymap.set("n", "<leader>rdu", function()
  REPLFactory():debug_unt()
end, { desc = "until line" })

vim.keymap.set({ "n", "v" }, "<leader>rdp", function()
  REPLFactory():debug_print()
end, { desc = "print variable" })

vim.keymap.set({ "n", "v" }, "<leader>rde", function()
  REPLFactory():debug_explore()
end, { desc = "explore object" })

vim.keymap.set("n", "<leader>rdE", function()
  REPLFactory():debug_explore("locals()")
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
  REPLFactory():send_code()
end, { desc = "Send Code to (R)un" })

-- config
-- coroutine may be helpful: https://github.com/stevearc/dressing.nvim/discussions/70

return M
