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
    -- "you-n-g/vim-slime", -- to fix conflict with toggleterm.
    -- branch = "patch-1",
    init = function()
      -- these two should be set before the plugin loads
      vim.g.slime_target = "neovim"
      -- vim.g.slime_no_mappings = true
    end,
    config = function()
      -- from neovim docs.
      vim.g.slime_input_pid = false
      vim.g.slime_suggest_default = true
      vim.g.slime_menu_config = false
      -- You might set both `g:slime_suggest_default = 0` and `g:slime_menu_config = 0` in cases where other plugins create terminals that you would never want to send text to.

      vim.g.slime_neovim_ignore_unlisted = false -- we must set this to enable discovery neovim supported by toggleterm.

      -- vim.g.slime_target = "neovim"
      vim.g.slime_python_ipython = 1
      if vim.fn.has("win32") == 1 then
        vim.api.nvim_set_keymap("n", "<c-c><c-u>", [[<cmd>SlimeSend0 "\x15"<CR>]], { noremap = true })
        vim.api.nvim_set_keymap("n", "<c-c><c-i>", [[<cmd>SlimeSend0 "\x03"<CR>]], { noremap = true })
        vim.api.nvim_set_keymap("n", "<c-c><c-d>", [[<cmd>SlimeSend0 "\x04"<CR>]], { noremap = true })
        vim.api.nvim_set_keymap("n", "<c-c><c-p>", [[<cmd>SlimeSend0 "\x1bk\x0d"<CR>]], { noremap = true }) -- k indicates upper in vim mode
        -- vim.api.nvim_set_keymap("n", "<c-c><c-p>", [[<cmd>SlimeSend0 "\x1b[1;2A\x0d"<CR>]], { noremap = true }) -- in other mode. But it does not work well
        vim.api.nvim_set_keymap("n", "<c-c><cr>", [[<cmd>SlimeSend0 "\x0d"<CR>]], { noremap = true })
        vim.keymap.set("n", "<c-c><cr>", function()
          -- vim.cmd([[TermExec cmd="\%paste"]])
          -- vim.fn.chansend(vim.g.slime_last_toggleterm_channel, "%paste")
          -- NOTE:: in windows, the \r will not work if we send other things in the same function
          vim.fn.chansend(vim.g.slime_last_toggleterm_channel, "\r")
        end, { noremap = true })
      else
        -- Just make the chatgpt faster
        vim.api.nvim_exec([[
          augroup SlimeKeymaps
            autocmd!
            autocmd FileType * if &filetype !=# 'chatgpt-input'
            \ | nnoremap <c-c><c-u> :SlimeSend0 "\x15"<CR>
            \ | nnoremap <c-c><c-i> :SlimeSend0 "\x03"<CR>
            \ | nnoremap <c-c><c-d> :SlimeSend0 "\x04"<CR>
            \ | nnoremap <c-c><c-p> :SlimeSend0 "\x1bk\x0d"<CR>
            \ | nnoremap <c-c><cr> :SlimeSend0 "\x0d"<CR>
            \ | endif
          augroup END
        ]], false)
      end

      vim.api.nvim_exec([[
augroup auto_slime_channel
  autocmd!
  autocmd BufEnter,WinEnter,TermOpen  * lua reset_slime()
augroup END]],
        false
      )
    end,
  },
}
