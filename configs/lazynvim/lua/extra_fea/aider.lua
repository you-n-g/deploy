--[[
Related projects
- https://github.com/aweis89/aider.nvim

TODO:
- `<alt>/` to enter into aider terminal in insert mode and press `/`
]]
--
local repl = require"extra_fea.repl_workflow"
local term_size = 12

local repl_inst = repl.REPLFactory()

-- local launch_cmd = [[key_shell.sh %s bash -c "aider --model \$CHAT_MODEL --weak-model \$CHAT_MODEL --no-show-model-warnings --editor \"nvim --cmd 'let g:flatten_wait=1' --cmd 'cnoremap wq lua vim.cmd(\\\"w\\\"); require\\\"snacks\\\".bufdelete()'\" --watch-files --subtree-only %s"]]
local launch_cmd = [[key_shell.sh %s myaider %s]]

-- It is not frequently used now
-- vim.keymap.set("n", "<leader>raL", function()
--   require("toggleterm").exec(string.format(launch_cmd, "azure_aider"), tonumber(vim.g.toggleterm_last_id), term_size)
-- end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal" })

local function run_aider(git_support, auto_commit)
  repl.toggle_aider_mode("/test")

  local current_file = vim.fn.expand("%")
  local extra_args = "--lint-cmd 'lua: luacheck --globals vim -- '" .. " " .. current_file
  
  if not auto_commit then
    extra_args = "--no-auto-commit " .. extra_args
  end
  
  local cmd = string.format(launch_cmd, "openai_lite", extra_args)
  
  if git_support then
    cmd = "git checkout -B aider && " .. cmd
  end
  
  require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), nil, nil, "vertical")
end

vim.keymap.set("n", "<leader>raL", function()
  run_aider(true, true)
end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal(git support)" })

vim.keymap.set("n", "<leader>ral", function()
  run_aider(false, false)
end, { noremap = true, silent = true, desc = "Run openai_lite commands in terminal (with current file)" })

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

vim.keymap.set("n", "<leader>raA", function()
  local buffers = vim.fn.getbufinfo({buflisted = 1})
  -- require"snacks".debug(buffers)
  local file_list = {}
  for _, buf in ipairs(buffers) do
    -- `and buf.hidden == 0` is not a good indicator
    if buf.listed == 1 and (buf.variables.buftype or "" == "") then
      table.insert(file_list, vim.fn.expand(buf.name))
    end
  end
  if #file_list > 0 then
    local cmd = "/add " .. table.concat(file_list, " ")
    require("toggleterm").exec(cmd, tonumber(vim.g.toggleterm_last_id), term_size)
  end
end, { noremap = true, silent = true, desc = "Add all file buffers to aider" })

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
