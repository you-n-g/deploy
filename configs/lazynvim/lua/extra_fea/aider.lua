--[[
Related projects
- https://github.com/aweis89/aider.nvim
]]
--
local repl = require"extra_fea.repl_workflow"
local term_size = 12

local repl_inst = repl.REPLFactory()

local launch_cmd = [[key_shell.sh %s bash -c "aider --model \$CHAT_MODEL --weak-model \$CHAT_MODEL --no-show-model-warnings --editor \"nvim --cmd 'let g:flatten_wait=1' --cmd 'cnoremap wq lua vim.cmd(\\\"w\\\"); require\\\"snacks\\\".bufdelete()'\" --watch-files --subtree-only %s"]]

-- It is not frequently used now
-- vim.keymap.set("n", "<leader>raL", function()
--   require("toggleterm").exec(string.format(launch_cmd, "azure_aider"), tonumber(vim.g.toggleterm_last_id), term_size)
-- end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal" })

vim.keymap.set("n", "<leader>raL", function()
  repl.config.aider_mode = true
  require("toggleterm").exec("git checkout -B aider && " .. string.format(launch_cmd, "openai_lite", vim.fn.expand("%")), tonumber(vim.g.toggleterm_last_id), term_size)
end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal" })

vim.keymap.set("n", "<leader>ral", function()
  repl.toggle_aider_mode(true)
  -- repl.config.aider_mode = true
  require("toggleterm").exec(string.format(launch_cmd, "openai_lite", "--no-auto-commit " .. vim.fn.expand("%")), tonumber(vim.g.toggleterm_last_id), term_size)
end, { noremap = true, silent = true, desc = "Run openai_lite commands in terminal(with current file)" })

vim.keymap.set("n", "<leader>rar", function()
  local cmd = "/read-only " .. vim.fn.expand(repl_inst:get_path_symbol())
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), term_size)
end, { noremap = true, silent = true, desc = "Send current file to aider in read-only mode" })

vim.keymap.set("n", "<leader>raa", function()
  local cmds = {
    "/add " .. vim.fn.expand(repl_inst:get_path_symbol()),
  }
  for _, cmd in ipairs(cmds) do
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), term_size)
  end
end, { noremap = true, silent = true, desc = "Add current file to aider" })

vim.keymap.set("n", "<leader>rae", function()
  -- NOTE: this depends on the correct setting
  -- opts = { window = { open = "smart" } },
  require("toggleterm").exec("/editor", tonumber(vim.g.toggleterm_last_id), term_size)
end, { noremap = true, silent = true, desc = "Open editor(/editor)" })

-- For a file buffer (the buffer is related to a disk file, not some nofile buffer),
-- run checktime when I enter it or before I want to change it.
vim.api.nvim_create_autocmd({"BufEnter", "CursorHold", "FocusGained"}, {
  pattern = "*",
  callback = function()
    if vim.fn.getbufvar(vim.fn.bufnr(), "&buftype") == "" then
      -- This prevents the `checktime` command from running on non-file buffers (e.g., terminal buffers, help buffers).
      vim.cmd("checktime")
    end
  end,
  desc = "Run checktime when entering a buffer or before changing it"
})
