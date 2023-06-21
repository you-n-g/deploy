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
    vim.api.nvim_feedkeys([[:SlimeSend0 "%paste"]] .. "\n", "n", false)
    vim.api.nvim_feedkeys([[:SlimeSend0 "\x0d"]] .. "\n", "n", false)
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
  vim.keymap.set({ "n", "x", "v" }, "<c-c><c-c>", sendContent, { noremap = true, desc = "send content" })
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

-- Configs
local config = {
  edit_before_send = false,
  goto_debug_when_fail = false,
}

local function edit_before_send(cmd)
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

-- Base class and methods

local BaseREPL = class("BaseREPL")

function BaseREPL:run_func()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand("%") .. " " .. get_current_function_name()
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
end

function BaseREPL:run_script()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand("%")
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

-- for all kinds of language

-- - Python
local PythonREPL = class("PythonREPL", BaseREPL)
PythonREPL.interpreter = "python"

function PythonREPL:launch_interpreter()
  edit_before_send("ipython")
end

function PythonREPL:test()
  local cmd = "pytest -s --pdb --disable-warnings " .. vim.fn.expand("%:p") .. "::" .. get_current_function_name(true)
  -- interact with user to edit `cmd`
  edit_before_send(cmd)
end

function PythonREPL:run_script()
  local cmd = "pypdb " .. vim.fn.expand("%")
  edit_before_send(cmd)
end

function PythonREPL:run_func()
  local cmd = self.interpreter .. " " .. vim.fn.expand("%") .. " "
  local func_name = get_current_function_name()
  -- NOTE: this is a hack for typer (the design is bad...)
  -- if `import typer` is included in the file, the replace the '_' with '-' in `cmd`
  if vim.fn.search("import typer", "nw") ~= 0 then
    func_name = string.gsub(func_name, "_", "-")
  end
  cmd = cmd .. func_name
  edit_before_send(cmd)
end

-- - Bash
local BashREPL = class("BashREPL", BaseREPL)
BashREPL.interpreter = "bash"

local function REPLFactory()
  local ft = vim.bo.filetype
  local repl_map = {
    python = PythonREPL,
    sh = BashREPL,
    bash = BashREPL,
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
-- TODO: `configs/nvim/yx/plugins_conf.vim` for doc test

-- config
-- coroutine may be helpful: https://github.com/stevearc/dressing.nvim/discussions/70

return M
