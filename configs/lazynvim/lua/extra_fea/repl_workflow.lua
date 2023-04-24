-- it is based on toggleterm.nvim and vim-slime.

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

-- Base class and methods

local BaseREPL = class("BaseREPL")

function BaseREPL:run_func()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand("%") .. " " .. get_current_function_name()
  vim.cmd(string.format("SlimeSend0 '%s'", cmd))
end

function BaseREPL:run_script()
  if self.interpreter == nil then
    print("No interpreter is set")
    return
  end
  local cmd = self.interpreter .. " " .. vim.fn.expand("%")
  vim.cmd(string.format("SlimeSend0 '%s'", cmd))
end

-- for all kinds of language

local PythonREPL = class("PythonREPL", BaseREPL)
PythonREPL.interpreter = "python"

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

vim.keymap.set("n", "<leader>rs", function()
  REPLFactory():run_func()
end, { desc = "Run script" })
vim.keymap.set("n", "<leader>rf", function()
  REPLFactory():run_func()
end, { desc = "Run function" })

vim.keymap.set("n", "<leader>rLp", [[<cmd>SlimeSend0 "ipython\n"<cr>]],  { desc = "Python" } )
