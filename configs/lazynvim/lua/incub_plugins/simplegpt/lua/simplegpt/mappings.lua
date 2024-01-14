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
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gs', send.to_clipboard, {noremap = true, silent = true, desc="send question2clipboard"})
  vim.keymap.set({'n', 'v'}, '<LocalLeader>gc', send.to_chatgpt, {noremap = true, silent = true, desc="send question2ChatGPT"})


  local script_path = (debug.getinfo(1, "S").source:sub(2))
  local script_dir = vim.fn.fnamemodify(script_path, ':h')
  local data_path = script_dir .. '/../../qa_tpls'
  print(data_path)

  vim.keymap.set('n', '<LocalLeader>gf',
    function ()
      require('telescope.builtin').find_files({ cwd = data_path, previewer = true })
    end, { noremap = true })
end
return M
