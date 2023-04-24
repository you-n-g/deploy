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
  vim.keymap.del({"n", "i", "v"}, key)
end

-- 拷贝当前buffer的相对路径
vim.api.nvim_set_keymap('n', 'yp', [[:lua vim.fn.setreg("\"", vim.fn.expand("%")); print(vim.fn.getreg("\""))<cr>]], {expr = false, noremap = true})
