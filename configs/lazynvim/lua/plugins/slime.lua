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
      vim.cmd([[

let g:slime_target = "neovim"
let g:slime_python_ipython = 1

" clear previous command
nnoremap <c-c><c-u> :SlimeSend0 "\x15"<CR>
nnoremap <c-c><c-i> :SlimeSend0 "\x03"<CR>
" Interupted command
" ^D	EOT	004	04	End of Transmission
nnoremap <c-c><c-d> :SlimeSend0 "\x04"<CR>
" `esc` `k`  `carriage return`
nnoremap <c-c><c-p> :SlimeSend0 "\x1bk\x0d"<CR>

" send <cr> to current repl
nnoremap <c-c><cr> :SlimeSend0 "\x0d"<CR>

if get(g:, "slime_target", "") == "neovim"
  augroup auto_channel
    autocmd!
    " autocmd TermEnter * let g:slime_last_channel = &channel
    autocmd BufEnter,WinEnter,TermOpen  * lua reset_slime()
  augroup END
end
    ]])
    end,
  },
}
