function reset_slime()
  -- this part is designed coupled with toggleterm
  if vim.api.nvim_get_var("slime_target") == "neovim" then
    if vim.o.filetype == "toggleterm" then
      vim.api.nvim_set_var("slime_last_toggleterm_channel", vim.o.channel)
    else
      local ok, last_channel = pcall(vim.api.nvim_get_var, "slime_last_toggleterm_channel")
      if ok then
        vim.api.nvim_buf_set_var(0, "slime_config", { jobid = last_channel })
      end
    end
  end
end

return {
  {
    "jpalardy/vim-slime",
    config = function()
      vim.g.slime_target = "neovim"

      vim.api.nvim_set_keymap("n", "<c-c><c-u>", [[<cmd>SlimeSend0 "\x15"<CR>]], { noremap = true })
      vim.api.nvim_set_keymap("n", "<c-c><c-i>", [[<cmd>SlimeSend0 "\x03"<CR>]], { noremap = true })
      vim.api.nvim_set_keymap("n", "<c-c><c-d>", [[<cmd>SlimeSend0 "\x04"<CR>]], { noremap = true })
      vim.api.nvim_set_keymap("n", "<c-c><c-p>", [[<cmd>SlimeSend0 "\x1bk\x0d"<CR>]], { noremap = true })
      vim.api.nvim_set_keymap("n", "<c-c><cr>", [[<cmd>SlimeSend0 "\x0d"<CR>]], { noremap = true })
      vim.api.nvim_exec([[
augroup auto_slime_channel
  autocmd!
  autocmd BufEnter,WinEnter,TermOpen  * lua reset_slime()
augroup END]], false)
    end,
  },
}
