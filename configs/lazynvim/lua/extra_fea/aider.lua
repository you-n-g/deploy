--[[
map <local>ral to send two command to terminal
key_shell.sh azure_aider
aider --model azure/$CHAT_MODEL  --no-auto-commit
aider = AiderREPL
]]
--
local repl = require"extra_fea/repl_workflow"

local repl_inst = repl.REPLFactory()

vim.keymap.set("n", "<leader>raL", function()
  local cmds = {
    "key_shell.sh azure_aider",
    "aider --model azure/$CHAT_MODEL --no-auto-commit",
  }
  for _, cmd in ipairs(cmds) do
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
  end
end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal" })


vim.keymap.set("n", "<leader>ral", function()
  local cmds = {
    "key_shell.sh azure_ad_aider",
    "aider --model azure/$CHAT_MODEL --no-auto-commit --no-show-model-warnings",
  }
  for _, cmd in ipairs(cmds) do
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
  end
end, { noremap = true, silent = true, desc = "Run azure_ad_aider commands in terminal" })

vim.keymap.set("n", "<leader>rar", function()
    local cmd = "/readonly " .. vim.fn.expand(repl_inst:get_path_symbol())
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
end, { noremap = true, silent = true, desc = "Send current file to aider in read-only mode" })

vim.keymap.set("n", "<leader>raa", function()
  local cmds = {
    "/add " .. vim.fn.expand(repl_inst:get_path_symbol()),
  }
  for _, cmd in ipairs(cmds) do
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), 12)
  end
end, { noremap = true, silent = true, desc = "Add current file to aider" })
