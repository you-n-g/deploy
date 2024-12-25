-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- vim.keymap.set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
-- vim.keymap.set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
-- vim.keymap.set("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
-- vim.keymap.set("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })
-- vim.keymap.set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
-- vim.keymap.set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" })
-- unmap the keymaps above. The esc will behave same like alt, which will trigger a lot of wrong combinations
for _, key in ipairs({ "<A-j>", "<A-k>" }) do
  vim.keymap.del({ "n", "i", "v" }, key)
end

-- disable map("n", "<leader>L", Util.changelog, {desc = "LazyVim Changelog"})
vim.keymap.del({"n"}, "<leader>L")

-- vim.keymap.del({"t"}, "<esc><esc>")  -- We may enter vim in terminal mode. So we need to remove this keymap
-- But when we update to new version. snaks.nvim use a different machanism

-- 拷贝当前buffer的相对路径
-- # TODO: yp for relative path, yP for absolute path. Please implement it with a for loop
local function copy_relative_path()
  for _, reg in ipairs({ "\"", "1", "+" }) do
    vim.fn.setreg(reg, vim.fn.expand("%"))
  end
  print("Relative path: " .. vim.fn.getreg("\""))
end

-- Function to copy the absolute path
local function copy_absolute_path()
  for _, reg in ipairs({ "\"", "1", "+" }) do
    vim.fn.setreg(reg, vim.fn.expand("%:p"))
  end
  print("Absolute path: " .. vim.fn.getreg("\""))
end

-- Keymap for copying the relative path
vim.keymap.set(
  "n",
  "yp",
  copy_relative_path,
  { expr = false, noremap = true, desc = "Copy relative path to the clipboard" }
)

-- Keymap for copying the absolute path
vim.keymap.set(
  "n",
  "yP",
  copy_absolute_path,
  { expr = false, noremap = true, desc = "Copy absolute path to the clipboard" }
)


-- this is usually useful when check the content in small window
vim.keymap.set("n", "<leader><tab>b", function()
  local bufnr = vim.api.nvim_get_current_buf()

  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = math.floor(0.99 * vim.o.columns),
    height = math.floor(0.99 * vim.o.lines),
    row = math.floor(0.1 * vim.o.lines),
    col = math.floor(0.1 * vim.o.columns),
    border = "single",
  })
  -- for the open window's terminal mode, map the <c-w>q to <c-\><c-n><c-w>q
  vim.keymap.set("t", "<C-w>q", "<C-\\><C-n><C-w>q", { desc = "Close terminal window" })

  -- Function to synchronize the cursor position between two windowskkk
  local function synchronize_cursor()
    -- Get the current window and buffer
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()
    -- Get the cursor position in the current window
    local cursor_pos = vim.api.nvim_win_get_cursor(current_win)
    -- Iterate over all windows
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      -- Check if the window is displaying the same buffer and is not the current window
      if win ~= current_win and vim.api.nvim_win_get_buf(win) == current_buf then
        -- Set the cursor position in the other window
        vim.api.nvim_win_set_cursor(win, cursor_pos)
      end
    end
  end

  -- Set up autocommand to synchronize the cursor position on cursor movement for the current buffer
  local sync_cursor_augroup = vim.api.nvim_create_augroup("SyncCursor", { clear = true })
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
    group = sync_cursor_augroup,
    buffer = bufnr,
    callback = synchronize_cursor,
  })

  -- Map <C-w>q to close the terminal window only for the floating window
  vim.api.nvim_create_autocmd("WinEnter", {
    group = sync_cursor_augroup,
    pattern = tostring(win_id),
    callback = function()
      vim.keymap.set("t", "<C-w>q", "<C-\\><C-n><C-w>q", { buffer = bufnr, desc = "Close terminal window" })
    end,
  })

  -- Remove the keymap and autocmds when the floating window is closed
  vim.api.nvim_create_autocmd("WinClosed", {
    group = sync_cursor_augroup,
    pattern = tostring(win_id),
    callback = function()
      vim.api.nvim_del_augroup_by_id(sync_cursor_augroup)
      vim.keymap.del("t", "<C-w>q", { buffer = bufnr })
    end,
  })
end, { expr = false, noremap = true, desc = "Open cur buffer in float window" })

vim.keymap.set("n", "<leader><tab><leader>", function()
  -- Check if the current buffer is associated with a file
  if vim.fn.expand("%") == "" then
    -- If not, open a new tab with an existing buffer that is associated with a file
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) and vim.fn.bufname(bufnr) ~= "" then
        vim.cmd("tab split | b" .. bufnr)
        return
      end
    end
  end
  -- If the current buffer is associated with a file, open a new tab with the current buffer
  vim.cmd("tab split")
end, { expr = false, noremap = true, desc = "Open new tab; but with current buffer or an existing buffer with a file" })

vim.api.nvim_set_keymap(
  "n",
  "<leader>sA",
  -- `only_sort_text=true` will only search text without filename
  -- https://github.com/nvim-telescope/telescope.nvim/issues/564
  -- [[:Telescope grep_string only_sort_text=true<cr>]],
  [[:lua require'telescope.builtin'.grep_string{ shorten_path = true, word_match = "-w", only_sort_text = false, search = '' }<cr>]],
  { expr = false, noremap = true, desc = "Search All!" }
  -- NOTE:
  -- <leader>sg/G uses live_grep, which will strictly search the word and not fuzzy enough.
  -- We prefer this grep_string when we fail to sG/g
)


-- change the window size of current window
-- The <C-up> and <C-down> are overridden by vim-visual-multi. But I can't disable it... So I have to resize it here.
local function win_change_width(n)
  vim.api.nvim_win_set_width(0, vim.api.nvim_win_get_width(0) + n)
end

local function win_change_height(n)
  vim.api.nvim_win_set_height(0, vim.api.nvim_win_get_height(0) + n)
end

for key, f in pairs({
  -- increase width
  ["<A-Right>"] = function()
    win_change_width(2)
  end,
  -- decrease width
  ["<A-Left>"] = function()
    win_change_width(-2)
  end,
  -- increase height
  ["<A-Up>"] = function()
    win_change_height(2)
  end,
  -- decrease height
  ["<A-Down>"] = function()
    win_change_height(-2)
  end,
}) do
  vim.keymap.set("n", key, f, { desc = "Resize" .. key })
end

-- TODO: ctrl+^ in insert mode into ctrl+^ in normal mode; To make it possible to switch buffer in insert mode
vim.keymap.set("i", "<C-^>", "<esc><C-^>a", { noremap = true, desc = "Switch buffer in insert mode" })

-- It fails to trigger auto import...
-- vim.keymap.set(
--   "n",
--   "<leader>ci",
--   [[exi<c-r>-]], { expr = false, noremap = true, desc = "Trigger Auto Import" })


-- Function to clear all extmarks in the current buffer
local function clear_all_extmarks()
  local bufnr = vim.api.nvim_get_current_buf()
  -- -1 means clear all namespaces
  for _, ns in ipairs{ "avante_selection", "avante_cursor" } do
    vim.api.nvim_buf_clear_namespace(bufnr, vim.api.nvim_create_namespace(ns), 0, -1)
  end
  print("Cleared all extmarks in the current buffer")
end

-- Keymap for clearing all extmarks in the current buffer
vim.keymap.set(
  "n",
  "<leader>uE",
  clear_all_extmarks,
  { expr = false, noremap = true, desc = "Clear all avante extmarks in the current buffer" }
)
