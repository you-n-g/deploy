vim.cmd [[
" syntax highlight related
" The colors come from
" https://stackoverflow.com/questions/16014361/how-to-set-a-custom-color-to-folded-highlighting-in-vimrc-for-use-with-putty
" https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg

augroup PythonOutlines
    au!
    " this is for simple words highlight syntax
    " autocmd FileType python,sh syntax match Outlines1 /\(^# # Outlines:\)\@=.*/
    " autocmd FileType python,sh syntax match Outlines2 /\(^# ## Outlines:\)\@=.*/
    " autocmd FileType python,sh hi Outlines1 cterm=bold ctermbg=blue guibg=LightYellow
    " autocmd FileType python,sh hi Outlines2 cterm=bold ctermbg=darkblue guibg=LightYellow

    " Below is for line hightlight
    if $TERM =~ "256"
        " They will not work in lua theme....
        " autocmd FileType python,sh,zsh hi Outlines1 cterm=bold ctermbg=017 ctermfg=White
        " autocmd FileType python,sh,zsh hi Outlines2 cterm=bold ctermbg=019 ctermfg=White
        " autocmd FileType python,sh,zsh hi cellDelimiterHi ctermbg=233 ctermfg=DarkGray
        autocmd FileType python,sh,zsh hi Outlines1 guifg=#51a0cf guibg=#1c2025
        autocmd FileType python,sh,zsh hi Outlines2 guifg=#6d8086 guibg=#1c2025
        autocmd FileType python,sh,zsh hi cellDelimiterHi guibg=#1c2025 
    else
        autocmd FileType python,sh,zsh hi Outlines1 cterm=bold ctermbg=darkblue ctermfg=White
        autocmd FileType python,sh,zsh hi Outlines2 cterm=bold ctermbg=blue ctermfg=White
        autocmd FileType python,sh,zsh hi cellDelimiterHi ctermbg=Black ctermfg=DarkGray
    endif

    autocmd FileType python,sh,zsh sign define cellLine linehl=cellDelimiterHi
    autocmd FileType python,sh,zsh sign define O1 linehl=Outlines1
    autocmd FileType python,sh,zsh sign define O2 linehl=Outlines2
    " 颜色是按下面的方式选出来的
    " autocmd FileType python,sh,zsh sign define cellLine linehl=BufferLineGroupSeparator
    " autocmd FileType python,sh,zsh sign define O1 linehl=BufferLineDevIconLuaInactive
    " autocmd FileType python,sh,zsh sign define O2 linehl=BufferLineDevIconDefaultInactive

    function! HighlightCellDelimiter()
      execute "sign unplace * group=cellsDelimiter file=".expand("%")
      execute "sign unplace * group=otl1 file=".expand("%")
      execute "sign unplace * group=otl2 file=".expand("%")

      for l:lnum in range(line("w0"), line("w$"))
        if getline(l:lnum) =~ "^# %%"
          execute "sign place ".l:lnum." line=".l:lnum." name=cellLine group=cellsDelimiter file=".expand("%")
        elseif getline(l:lnum) =~ "^# \\+# *Outlines:"
          execute "sign place ".l:lnum." line=".l:lnum." name=O1 group=otl1 file=".expand("%")
        elseif getline(l:lnum) =~ "^# \\+## *Outlines:"
          execute "sign place ".l:lnum." line=".l:lnum." name=O2 group=otl2 file=".expand("%")
        endif
      endfor
    endfunction

    autocmd! CursorMoved *.py,*.sh call HighlightCellDelimiter()
augroup END


augroup JavaOutlines
    au!
    " Below is for line hightlight
    if $TERM =~ "256"
        autocmd FileType java hi JavaOutlines1 cterm=bold ctermbg=017 ctermfg=White
        autocmd FileType java hi JavaOutlines2 cterm=bold ctermbg=019 ctermfg=White
    else
        autocmd FileType java hi JavaOutlines1 cterm=bold ctermbg=darkblue ctermfg=White
        autocmd FileType java hi JavaOutlines2 cterm=bold ctermbg=blue ctermfg=White
    endif

    autocmd FileType java sign define javaO1 linehl=JavaOutlines1
    autocmd FileType java sign define javaO2 linehl=JavaOutlines2

    function! HighlightJavaOL()
      execute "sign unplace * group=javaotl1 file=".expand("%")
      execute "sign unplace * group=javaotl2 file=".expand("%")

      for l:lnum in range(line("w0"), line("w$"))
        if getline(l:lnum) =~ "^\\s*// *# *Outlines:"
          execute "sign place ".l:lnum." line=".l:lnum." name=javaO1 group=javaotl1 file=".expand("%")
        elseif getline(l:lnum) =~ "^\\s*// *## *Outlines:"
          execute "sign place ".l:lnum." line=".l:lnum." name=javaO2 group=javaotl2 file=".expand("%")
        endif
      endfor
    endfunction

    autocmd! CursorMoved *.java call HighlightJavaOL()
augroup END
]]

-- Add a virtual "--------" delimiter to the end of every `# %%` cell-delimiter
-- line so it is visually obvious where the cell finishes even when there is no
-- following text.  We do this with an extmark that places Comment-highlighted
-- virtual text at the end of the line.  The implementation is kept in Lua so
-- it works consistently with modern Neovim themes.

local ns = vim.api.nvim_create_namespace("cellsDelimiterVT")
-- Bright colour for right-aligned cell delimiter
vim.api.nvim_set_hl(0, "CellDelimiterBright", { fg = "#FFD75F" })

local function add_virtual_cell_delimiter()
  -- Restrict to the filetypes we use for notebook-style cells
  local ft = vim.bo.filetype
  if ft ~= "python" and ft ~= "sh" and ft ~= "zsh" then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  -- Clear previously placed extmarks in the visible region
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local start_line = vim.fn.line("w0") - 1 -- 0-indexed
  local end_line = vim.fn.line("w$")       -- exclusive

  for lnum = start_line, end_line - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    if line:match("^# %%") then
      -- Add a right-aligned dashed line that fills the remaining space
      local win_width  = vim.api.nvim_win_get_width(0)
      local line_len   = vim.fn.strdisplaywidth(line)
      local dash_count = math.max(win_width - line_len - 1, 0)
      local dashes     = dash_count > 0 and (" " .. string.rep("-", dash_count)) or ""

      vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, -1, {
        virt_text = { { dashes, "CellDelimiterBright" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  end
end

-- Update the virtual text whenever the cursor moves, window is entered, or scrolled
-- Autocmds to update virtual cell delimiter
vim.api.nvim_create_autocmd({ "CursorMoved", "BufWinEnter", "WinResized" }, {
  pattern = { "*.py", "*.sh", "*.zsh" },
  callback = add_virtual_cell_delimiter,
})

-- WinScrolled event does not support pattern matching, so we filter by filetype in the callback
vim.api.nvim_create_autocmd("WinScrolled", {
  callback = function()
    local ft = vim.bo.filetype
    if ft == "python" or ft == "sh" or ft == "zsh" then
      add_virtual_cell_delimiter()
    end
  end,
})
