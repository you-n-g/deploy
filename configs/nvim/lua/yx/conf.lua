-- lua cheatsheets
-- - https://github.com/nanotee/nvim-lua-guide
-- - https://devhints.io/lua
-- APIs (列几个使用频率较高的)
-- - 和vim直接相关的
--   - nvim api: help api,  可以通过 vim.api.XXX 调用
--     - vim.api.nvim_set_keymap('i', '<Tab>', 'v:lua.smart_tab()', {expr = true, noremap = true})
--       - expr 代表是否要用 vim script 重新evaluate 一下，再执行
--   - vim.fn.XXX 直接调用vimscripts 的functions
--   - vim eval: help eval, 可以通过 vim.fn.XXX 调用
--   - vim.cmd("new") 可以执行一片命令, vim.api.nvim_command() 用于执行一行命令
-- - 通用的语法
--   - print(vim.inspect(<table>))    -- 可以直接方便地按 key, value的形式展示table的内容， 但是无法展示object的内容
--   - TODO: 怎么看object的其他属性


-- 拷贝当前buffer的相对路径
vim.api.nvim_set_keymap('n', 'yp', [[:lua vim.fn.setreg("\"", vim.fn.expand("%")); print(vim.fn.getreg("\""))<cr>]], {expr = false, noremap = true})
