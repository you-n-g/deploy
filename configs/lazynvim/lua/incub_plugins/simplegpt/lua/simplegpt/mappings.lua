local M = {}
local loader = require"simplegpt.loader"
local tpl = require"simplegpt.tpl"
local send = require"simplegpt.send" 

function M.setup()
  vim.keymap.set('n', '<LocalLeader>gl', loader.load_reg, {noremap = true, silent = true, desc="load registers"})
  vim.keymap.set('n', '<LocalLeader>gd', loader.dump_reg, {noremap = true, silent = true, desc="dump registers"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>ge', function ()
    local rqa = tpl.RegQAUI()
    rqa:build()
  end, {noremap = true, silent = true, desc="edit registers"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gs', send.to_clipboard, {noremap = true, silent = true, desc="send question"})
end

return M
