set ai "auto indent
set expandtab
set tabstop=4
set shiftwidth=4
autocmd FileType c,cpp setlocal shiftwidth=2 tabstop=2
" set textwidth=120  " vim keeps break lines when we are editing long strings
set number
set relativenumber
" augroup FIX_COC_EXP
"     autocmd!
"     " coc-explorer好像 relativenumber 显示有问题
"     " autocmd FileType * setlocal relativenumber
"     autocmd FileType coc-explorer setlocal norelativenumber
"     autocmd FileType coc-explorer setlocal nonumber
" augroup END
set scrolloff=10 " always keep 10 lines visible.
set ignorecase
set smartcase

" to automatically load the `.nvimrc`
set exrc
set secure

set mouse=a  " enable mouse, shift is required if you want to click like before

" for filename completion in commands like COMMAND=/file/name
" http://superuser.com/questions/598270/getting-rid-of-characters-when-doing-gf-in-vim
set isfname-==

set fileencodings=utf8,gbk
" This is a list of character encodings considered when **starting to edit** an existing file.
" 注意 encoding/enc 是用于设置 RPC communication 的编码，不太一样



" Go to the last cursor location when a file is opened, unless this is a
" git commit (in which case it's annoying)
au BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") && &filetype != "gitcommit" |
        \ execute("normal `\"") |
    \ endif
" https://stackoverflow.com/a/774599
" 如果不行一般是因为权限问题: sudo chown user: ~/.viminfo
" 这个插件和 stop_open.vim 有冲突。。


" highlight current line
set cursorline
set cursorcolumn


" 这个得在前面， 不然会对后面的定义有影响, 配合 vim-which-key
let g:mapleader = "\<Space>"
let g:maplocalleader = ','

" Buffer related
" :bd XXX 可以关闭buffer, 关闭buffer，
" c+^ 是可以在最近的两个buffer之间切换的
nnoremap gb :ls<CR>:b<Space>
nnoremap <silent> <Leader>rc  :<C-u>source $MYVIMRC<CR>


" for quick-scope: the color setting must be before the colorscheme
augroup qs_colors
  autocmd!
  autocmd ColorScheme * highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=107 cterm=underline
  autocmd ColorScheme * highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=68 cterm=underline
augroup END




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

" 确认当前位置的highlight 规则-
" 以前: https://vim.fandom.com/wiki/Identify_the_syntax_highlighting_group_used_at_the_cursor
" nnoremap <F10> :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
"         \ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
"         \ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>
" 有treesitter之后 https://github.com/nvim-treesitter/nvim-treesitter/issues/519#issuecomment-712533798
" - TSHighlightCapturesUnderCursor

" NOTE: we want to highlight  Special notes
" 但是好像没有用, 感觉内部有一个奇怪的 priofity， 导致替换不了
" syntax match Todo "\v.*" containedin=.*Comment
" syntax match Todo "\v.*" containedin=.*Comment contained conceal
augroup syntax_todo_etc
    autocmd!
    " autocmd Syntax * syntax match Todo /\v(TODO|NOTE|FIXME|OPTIMIZE|XXX)/ containedin=.*Comment
    " autocmd Syntax * syntax match jdoc /\v(\@author|\@param|\@return|\@see)/ containedin=.*Comment
    " autocmd FileType * match Todo /\v (TODO|NOTE|FIXME|OPTIMIZE|XXX):/
    autocmd FileType * match Todo /\(\(\s\)\@<=\|^\)\(TODO\|NOTE\|FIXME\|OPTIMIZE\|XXX\):/
    " (#|"|--)
    " 用原生的零宽断言: \(\(\s\)\@<=\|^\)HAHA:
augroup END
" FIXME: 这里用 match有点牵强， 肯定存在更优的解的


" 快速替换
" Highlight 是为了让用户看清楚现在哪些词会被替换
nnoremap <expr> <plug>HighlightReplaceW '/\<'.expand('<cword>').'\><CR>``:%s/\<'.expand('<cword>').'\>/'.expand('<cword>').'/g<left><left>'
" 这里蕴含了单引号字符串包含单引号的技巧(''代表', 后来发现不用了)
" - https://vi.stackexchange.com/a/9046
" - :h literal-string
vnoremap <expr> <plug>VHighlightReplaceW '/\<'.expand('<cword>').'\><CR>``:s/\<'.expand('<cword>').'\>/'.expand('<cword>').'/g<left><left>'
nmap <leader>rp <plug>HighlightReplaceW
vmap <leader>rp <plug>VHighlightReplaceW

" 这是不用分词符版本的
nnoremap <expr> <plug>HighlightReplace ':%s/'.expand('<cword>').'/'.expand('<cword>').'/g<left><left>'
vnoremap <expr> <plug>VHighlightReplace ':s/'.expand('<cword>').'/'.expand('<cword>').'/g<left><left>'
nmap <leader>rP <plug>HighlightReplace
vmap <leader>rP <plug>VHighlightReplace


" 只替换当前行 replace row
nnoremap <expr> <plug>HighlightReplaceRow ':s/\<'.expand('<cword>').'\>/'.expand('<cword>').'/g<left><left>'
vnoremap <expr> <plug>VHighlightReplaceRow ':s/\<'.expand('<cword>').'\>/'.expand('<cword>').'/g<left><left>'
nmap <leader>rr <plug>HighlightReplaceRow
vmap <leader>rP <plug>VHighlightReplaceRow

" switch recent buffer in insert mode(C-o可以保持不离开insert mode)
inoremap <C-^> <C-o><C-^>

" 个人喜欢的快速移动
" - 在insert mode下快速到行尾
inoremap <C-e> <C-o>$


" 禁止vim存储特定名字的文件(防止按错)
" https://stackoverflow.com/a/6211489
" TODO: [] 也加上...
autocmd BufWritePre [:;"'\[\]]*
\   try | echoerr 'Forbidden file name: ' . expand('<afile>') | endtry
" 如果实在想存可一这么操作
" :noa w '


" Remove trailing whitespaces when saving python files
autocmd FileType python autocmd BufWritePre <buffer> if &modified | %s/\s\+$//e | endif

augroup highlight_yank
    autocmd!
    " 我把这个 highlight 的时间缩短的原因是:
    " 有时候highlight没结束，做操作时会导致neovim崩
    au TextYankPost * silent! lua vim.highlight.on_yank{higroup="IncSearch", timeout=200}
augroup END


