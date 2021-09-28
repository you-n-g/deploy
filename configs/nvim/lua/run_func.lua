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
local M = {}

function M.get_current_function_name()
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

    return (ts_utils.get_node_text(expr:child(1)))[1]
end

return M
