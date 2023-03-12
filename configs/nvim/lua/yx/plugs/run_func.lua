-- 捣鼓了半天没成功， 最后从网上抄了一些代码
-- function _G.rf()
--     local ts_utils = require 'nvim-treesitter.ts_utils'
--     local node = ts_utils:get_node_at_cursor()
--     print(node)
--     print(node:get_node_text(0))
--     -- print(ts_utils:get_node_text(node, 0))
--
--     -- print(tstree:root())
--     -- print(ts_utils:get_node_text(node, bufnr))
-- end

-- 下面的代码是基于下面的讨论
-- https://www.reddit.com/r/neovim/comments/nnru7r/how_do_i_get_the_name_of_the_current_function_i/
-- 这个版本还有如下问题
-- - 遇到comments，就直接变成<node source了>
local ts_utils = require'nvim-treesitter.ts_utils'
-- local query = require'vim.treesitter.query'
-- get_node_text 说是新版的得从这里拿，但是这里没找到怎么拿
local M = {}

function M.get_current_function_name(find_cls, sep)
    -- default value is false
    find_cls = (find_cls == nil and false) or find_cls
    sep = (sep == nil and "::") or sep

    local current_node = ts_utils.get_node_at_cursor()

    if not current_node then return "" end

    local expr = current_node

    while expr do
        -- in lua, the definition of function are with type "function"
        if expr:type() == 'function_definition' or  expr:type() == 'function' then
            break
        end
        expr = expr:parent()
    end

    if not expr then return "" end

    -- TODO: 我觉得这里应该有更方便的获得 node function name的方法
    local name_index = 1
    -- print(expr:child(name_index):type())
    if expr:child(name_index):type() == "(" then
        -- this is for some bash scripts without `function` decoration. So the first word should be function name
        name_index = 0
    end
    -- query.get_node_text
    local func_name = (ts_utils.get_node_text(expr:child(name_index)))[1]
    if not find_cls then return func_name end

    -- find class name
    while expr do
        -- in lua, the definition of function are with type "function"
        if expr:type() == 'class_definition' then
            break
        end
        expr = expr:parent()
    end

    if not expr or expr:type() ~= "class_definition" then return func_name end

    local cls_name = (ts_utils.get_node_text(expr:child(1)))[1]
    return cls_name .. sep .. func_name
end

return M
