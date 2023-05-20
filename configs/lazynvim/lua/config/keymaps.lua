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

-- 拷贝当前buffer的相对路径
vim.api.nvim_set_keymap(
  "n",
  "yp",
  [[:lua vim.fn.setreg("\"", vim.fn.expand("%")); print(vim.fn.getreg("\""))<cr>]],
  { expr = false, noremap = true }
)
-- this is usually useful when check the content in small window
vim.keymap.set("n", "<leader><tab>b", function()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = math.floor(0.8 * vim.o.columns),
    height = math.floor(0.8 * vim.o.lines),
    row = math.floor(0.1 * vim.o.lines),
    col = math.floor(0.1 * vim.o.columns),
    border = "single",
  })
end, { expr = false, noremap = true, desc = "Open cur buffer in float window" })

vim.api.nvim_set_keymap(
  "n",
  "<leader>sA",
  -- `only_sort_text=true` will only search text without filename
  -- https://github.com/nvim-telescope/telescope.nvim/issues/564
  -- [[:Telescope grep_string only_sort_text=true<cr>]],
  [[:lua require'telescope.builtin'.grep_string{ shorten_path = true, word_match = "-w", only_sort_text = false, search = '' }<cr>]],
  { expr = false, noremap = true, desc = "Search All!" }
)
