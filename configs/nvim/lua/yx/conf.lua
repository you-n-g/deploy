-- lua cheatsheets
-- - https://github.com/nanotee/nvim-lua-guide
-- - https://devhints.io/lua
-- APIs (列几个使用频率较高的)
-- - nvim api: help api,  可以通过 vim.api.XXX 调用
-- - vim.fn.XXX 直接调用vimscripts 的functions
-- - vim eval: help eval, 可以通过 vim.fn.XXX 调用
-- - vim.cmd("new") 可以执行一片命令, vim.api.nvim_command() 用于执行一行命令
-- vim.api.nvim_set_keymap('i', '<Tab>', 'v:lua.smart_tab()', {expr = true, noremap = true})

