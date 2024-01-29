local M = {}
local loader = require"simplegpt.loader"
local tpl = require"simplegpt.tpl"
local send = require"simplegpt.send" 

function M.setup()
  vim.keymap.set('n', '<LocalLeader>gl', loader.tele_load_reg, {noremap = true, silent = true, desc="load registers"})
  vim.keymap.set('n', '<LocalLeader>gD', loader.input_dump_name, {noremap = true, silent = true, desc="dump registers"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>ge', function ()
    local rqa = tpl.RegQAUI()
    rqa:build()
  end, {noremap = true, silent = true, desc="edit registers"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gs', send.to_clipboard, {noremap = true, silent = true, desc="send question2clipboard"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gc', send.to_chatgpt, {noremap = true, silent = true, desc="send question2ChatGPT"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gr', send.get_response, {noremap = true, silent = true, desc="send to get direct response"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gd', send.get_diff, {noremap = true, silent = true, desc="send to get response with diff"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gR', send.resume_popup, {noremap = true, silent = true, desc="resume last popup"})
  vim.keymap.set('n', '<LocalLeader>gf', loader.tele_load_reg, { noremap = true, desc="load tpl via telescope" })
end
return M
