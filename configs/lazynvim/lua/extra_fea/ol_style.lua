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
