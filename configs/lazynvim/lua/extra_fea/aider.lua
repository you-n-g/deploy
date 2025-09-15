--[[
Related projects
- https://github.com/aweis89/aider.nvim

TODO:
- `<alt>/` to enter into aider terminal in insert mode and press `/`
]]
local repl = require"extra_fea.repl_workflow"
local term_size = 12

local repl_inst = repl.REPLFactory()

-- local launch_cmd = [[key_shell.sh %s bash -c "aider --model \$CHAT_MODEL --weak-model \$CHAT_MODEL
--   --no-show-model-warnings --editor \"nvim --cmd 'let g:flatten_wait=1'
--   --cmd 'cnoremap wq lua vim.cmd(\\\"w\\\"); require\\\"snacks\\\".bufdelete()'\""
--   --watch-files --subtree-only %s"]]
local launch_cmd = [[key_shell.sh %s env -u CHAT_MODEL myaider %s]]

-- It is not frequently used now
-- vim.keymap.set("n", "<leader>raL", function()
--   require("toggleterm").exec(string.format(launch_cmd, "azure_aider"), repl.get_toggleterm_last_id(), term_size)
-- end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal" })


local function toggle_aider_mode(target, term_id)
  -- Get or initialize terminal-specific mode
  term_id = term_id or repl.get_toggleterm_last_id()
  local term_mode = repl.config.term_modes and repl.config.term_modes[term_id] or ""

  if target ~= nil then
    -- Initialize term_modes table if needed
    repl.config.term_modes = repl.config.term_modes or {}
    repl.config.term_modes[term_id] = target
  else
    local modes = {"", "/test", "/run"}
    local next_index = ((repl.find_index(modes, term_mode) or 0) % #modes) + 1
    -- Initialize term_modes table if needed
    repl.config.term_modes = repl.config.term_modes or {}
    repl.config.term_modes[term_id] = modes[next_index]
  end

  -- Update global config with current terminal's mode
  P(repl.config.term_modes[term_id])
end

vim.keymap.set("n", "<leader>ram", toggle_aider_mode, { desc = "Toggle Aider Mode." })


local function exec_aider(final_cmd)
  require("toggleterm").exec(final_cmd, repl.get_toggleterm_last_id(), nil, nil, "vertical")
  toggle_aider_mode("/test", repl.get_toggleterm_last_id())
end

local function run_aider(new_branch_mode)
  local current_file = vim.fn.expand("%")
  -- local extra_args = "--lint-cmd 'lua: luacheck --globals vim -g -u -r -a -- '" .. " " .. current_file
  local extra_args = "--lint-cmd 'lua: true '" .. " " .. current_file
  if not new_branch_mode then
    extra_args = "--no-auto-commit " .. extra_args
  end

  local model = vim.fn.system("tmux show-env llm_aider | cut -d= -f2"):gsub("%s+", "")
  if model == "" or model:match("^unknown") or model:match("^-") then
    model = "openai_lite"  -- default value if llm_aider is not set or invalid
  end
  local cmd = string.format(launch_cmd, model, extra_args)
  if new_branch_mode then
    vim.ui.input({ prompt = "Branch name for new branch:", default = "aider" }, function(branch)
      local final_cmd = cmd
      if branch and branch ~= "" then
        final_cmd = string.format("git checkout -B %s && %s", branch, cmd)
      end
      exec_aider(final_cmd)
    end)
  else
    exec_aider(cmd)
  end
end

vim.keymap.set("n", "<leader>raL", function()
  run_aider(true)
end, { noremap = true, silent = true, desc = "Run azure_aider commands in terminal(git support)" })

vim.keymap.set("n", "<leader>ral", function()
  run_aider(false)
end, { noremap = true, silent = true, desc = "Run openai_lite commands in terminal (with current file)" })

vim.keymap.set("n", "<leader>rar", function()
  local cmd = "/read-only " .. vim.fn.expand(repl_inst:get_path_symbol())
  require("toggleterm").exec(cmd, repl.get_toggleterm_last_id(), term_size)
end, { noremap = true, silent = true, desc = "Send current file to aider in read-only mode" })

vim.keymap.set("n", "<leader>raa", function()
  local cmds = {
    "/add " .. vim.fn.expand(repl_inst:get_path_symbol()),
  }
  for _, cmd in ipairs(cmds) do
    require("toggleterm").exec(cmd, repl.get_toggleterm_last_id(), term_size)
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
    require("toggleterm").exec(cmd, repl.get_toggleterm_last_id(), term_size)
  end
end, { noremap = true, silent = true, desc = "Add all file buffers to aider" })

vim.keymap.set("n", "<leader>rae", function()
  -- NOTE: this depends on the correct setting
  -- opts = { window = { open = "smart" } },
  require("toggleterm").exec("/editor", repl.get_toggleterm_last_id(), term_size)
end, { noremap = true, silent = true, desc = "Open editor(/editor)" })


-- For a file buffer (the buffer is related to a disk file, not some nofile buffer),
-- run checktime when I enter it or before I want to change it.
vim.api.nvim_create_autocmd({"BufEnter", "CursorHold", "FocusGained"}, {
  pattern = "*",
  callback = function()
    local bufnr = vim.fn.bufnr()
    local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
    -- check if buffer has 'nofile', 'terminal', 'help', etc
    if buftype ~= "" then
      return
    end
    local filename = vim.api.nvim_buf_get_name(bufnr)
    -- Empty name means no file, skip
    if filename == "" then
      return
    end
    -- Check if the file actually exists
    if vim.loop.fs_stat(filename) then
      vim.cmd("checktime")
    end
  end,
  desc = "Run checktime when entering a buffer or before changing it"
})

vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = ".aider.*",
  callback = function()
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end,
  desc = "Make .aider.* files read-only"
})
