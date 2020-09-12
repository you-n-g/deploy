call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'
Plug 'majutsushi/tagbar'
Plug 'fatih/vim-go'
Plug 'tomtom/tcomment_vim'
Plug 'nvie/vim-flake8'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" Plug 'heavenshell/vim-pydocstring', { 'do': 'make install' }
Plug 'tell-k/vim-autopep8'
Plug 'dhruvasagar/vim-table-mode'
Plug 'morhetz/gruvbox'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nathanaelkane/vim-indent-guides'

" 这里需要依赖 https://github.com/ryanoasis/nerd-fonts, 需要在本地安装字体
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'mhinz/vim-startify'
Plug 'vim-ctrlspace/vim-ctrlspace'
Plug 'liuchengxu/vim-which-key'

" Plug 'vim-vdebug/vdebug'   " 等待确认这个插件没有问题,
" 希望这个插件可以代替vscode

" Plug 'wellle/tmux-complete.vim'  #
" 好是好，但是我tmux窗口太多了，会引起性能问题

Plug 'jpalardy/vim-slime' " , { 'for': 'python' } 加上这个之后会导致只对python有用
Plug 'hanschen/vim-ipython-cell', { 'for': 'python' }

Plug 'jupyter-vim/jupyter-vim'
Plug 'goerz/jupytext.vim' " `pip install jupytext` is required
Plug 'unblevable/quick-scope'
Plug 'tpope/vim-repeat'
Plug 'jiangmiao/auto-pairs'
Plug 'kshenoy/vim-signature'
Plug 'airblade/vim-gitgutter'

Plug 'wellle/context.vim'
Plug 'machakann/vim-sandwich'

Plug 'ludovicchabant/vim-gutentags'  " 自动生成更新ctags
" tags围绕tag stack进行,  ctrl+t pop操作， ctrl+] push操作(如果找得到顺便jump一下)

Plug 'puremourning/vimspector'
Plug 'kana/vim-submode'

" NOTE: 还没看具体教程
" Plug 'terryma/vim-multiple-cursors'
Plug 'mg979/vim-visual-multi'

Plug 'kkoomen/vim-doge'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

call plug#end()


" settings -------------------------

set ai "auto indent
set expandtab
set tabstop=4
set shiftwidth=4
autocmd FileType c,cpp setlocal shiftwidth=2 tabstop=2
set textwidth=120
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


" for filename completion in commands like COMMAND=/file/name
" http://superuser.com/questions/598270/getting-rid-of-characters-when-doing-gf-in-vim
set isfname-==

" examples to ignore
" ignore a directory on top level
" let g:NERDTreeIgnore += ['^models$']
" let g:ctrlp_custom_ignore = {
"   \ 'dir':  '\vmodels$',
"   \ }

" coc-lists相关的都可以用 project下的 .ignore
" 文件代替，当做它是.gitignore用????

" list.source.files.excludePatterns 是coclist file的ignore
" 这个在deployment里面有自己动设置参数的脚本
"
" list.source.grep.excludePatterns 实在是不会用,  所以workaround方法如下
" 就是把那些大文件放到别的地方再Link过来，默认coclist grep不会follow link


" Go to the last cursor location when a file is opened, unless this is a
" git commit (in which case it's annoying)
au BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") && &filetype != "gitcommit" |
        \ execute("normal `\"") |
    \ endif
" https://stackoverflow.com/a/774599
" 如果不行一般是因为权限问题: sudo chown user: ~/.viminfo


" highlight current line
set cursorline

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

let g:gruvbox_contrast_dark="hard"
" let g:gruvbox_contrast_dark="soft"
set background=dark
colorscheme gruvbox

map <F9>p :call CompilePython()<cr>
func! CompilePython()
    exec "w"
    exec "!echo -e '\033[1;34m-----------here\ is\ the\ ans\ of\ %----------\033[0m';python \"%\""
endfunc

map <F9>s :call RunShell()<cr>
func! RunShell()
    exec "w"
    exec "!echo -e '\033[1;34m-----------here\ is\ the\ ans\ of\ %----------\033[0m';bash \"%\""
endfunc

map <F9>c :call CompileRunCpp()<CR>
func! CompileRunCpp()
    exec "w"
    exec "!echo -e '\033[1;32mcompiling.....\033[0m';g++ -std=c++11 \"%\" -o \"%:r.exe\";echo -e '\033[1;34m-----------here_is_the_ans_of_%----------\033[0m';./\"%:r.exe\";echo -e '\033[1;33mend...\033[0m';rm \"%:r.exe\""
    "exec "!./%:r.exe"
endfunc

map <F9>j :call CompileRunJava()<CR>
func! CompileRunJava()
    exec "w"
    exec "!echo -e '\033[1;32mcompiling.....\033[0m';javac %;echo -e '\033[1;34m-----------here_is_the_ans_of_%----------\033[0m';java %:r;echo -e '\033[1;33mend...\033[0m';rm %:r.class"
endfunc

map <F9>g :call CompileRunGo()<CR>
func! CompileRunGo()
    exec "w"
    exec "!go run %"
endfunc

nnoremap <F11> :set spell!<CR>


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
        autocmd FileType python,sh hi Outlines1 cterm=bold ctermbg=017 ctermfg=White
        autocmd FileType python,sh hi Outlines2 cterm=bold ctermbg=019 ctermfg=White
        autocmd FileType python,sh hi cellDelimiterHi ctermbg=233 ctermfg=DarkGray
    else
        autocmd FileType python,sh hi Outlines1 cterm=bold ctermbg=darkblue ctermfg=White
        autocmd FileType python,sh hi Outlines2 cterm=bold ctermbg=blue ctermfg=White
        autocmd FileType python,sh hi cellDelimiterHi ctermbg=Black ctermfg=DarkGray
    endif

    autocmd FileType python,sh sign define cellLine linehl=cellDelimiterHi
    autocmd FileType python,sh sign define O1 linehl=Outlines1
    autocmd FileType python,sh sign define O2 linehl=Outlines2

    function! HighlightCellDelimiter()
      execute "sign unplace * group=cellsDelimiter file=".expand("%")
      execute "sign unplace * group=otl1 file=".expand("%")
      execute "sign unplace * group=otl2 file=".expand("%")

      for l:lnum in range(line("w0"), line("w$"))
        if getline(l:lnum) =~ "^# %%"
          execute "sign place ".l:lnum." line=".l:lnum." name=cellLine group=cellsDelimiter file=".expand("%")
        elseif getline(l:lnum) =~ "^# # Outlines:"
          execute "sign place ".l:lnum." line=".l:lnum." name=O1 group=otl1 file=".expand("%")
        elseif getline(l:lnum) =~ "^# ## Outlines:"
          execute "sign place ".l:lnum." line=".l:lnum." name=O2 group=otl2 file=".expand("%")
        endif
      endfor
    endfunction

    autocmd! CursorMoved *.py,*.sh call HighlightCellDelimiter()
augroup END



" 快速替换
" TODO: 这个highlight 是个啥鬼.... 好像根本不需要是不是....
" - 可能我只是想写一个替换highlight的快捷键，结果弄错了
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



"
" The plugins I always need -------------------------
" https://github.com/neovim/neovim/wiki/Related-projects#plugins
"

" Plug 'liuchengxu/vim-which-key'
" I should before any key define based on vim-which-key

set timeoutlen=500 " By default timeoutlen is 1000 ms
call which_key#register('<Space>', "g:which_key_map")
nnoremap <silent> <leader>      :<c-u>WhichKey '<Space>'<CR>
vnoremap <silent> <leader>      :<c-u>WhichKeyVisual '<Space>'<CR>
" nnoremap <silent> <localleader> :<c-u>WhichKey  ','<CR>
" vnoremap <silent> <localleader> :<c-u>WhichKeyVisual ','<CR>
let g:which_key_map =  {}
" 我理解这里的所有的map命令 CMD 最后都会变成 :CMD<CR>



"
" ctrlp.vim
" https://github.com/kien/ctrlp.vim
" let g:ctrlp_working_path_mode = 'wa'
" nnoremap <silent> <leader>cp  :<C-u>CtrlPClearCache<CR>
" nnoremap <silent> <C-P>  :<C-u>CocList files<CR>
nnoremap <silent> <C-P>  :<C-u>Files<CR>
let g:ctrlp_map = ''
let g:ctrlp_cmd = ''




"
" vimwiki http://www.vim.org/scripts/script.php?script_id=2226
"
" map tb :VimwikiTable
" map t<space> <Plug>VimwikiToggleListItem
let g:vimwiki_hl_headers = 1
" let g:vimwiki_conceallevel = 0


"
" Nerdtree http://www.vim.org/scripts/script.php?script_id=1658
"
nnoremap <silent> <F7> :NERDTreeToggle<CR>
let NERDTreeIgnore=['\.pyc$', '\.orig$', '\.pyo$']


"
" Tagbar http://www.vim.org/scripts/script.php?script_id=3465
"
" nnoremap <silent> <F8> :TlistToggle<CR>
nnoremap <silent> <F8> :TagbarToggle<CR>
let g:tagbar_sort = 0


"
" vim-flake8 , PyFlakes to find static programming errors and  PEP8 ...
"   git clone https://github.com/nvie/vim-flake8 ~/.vim/bundle/
"   sudo apt-get install python-flake8
let g:no_flake8_maps=1
" autocmd BufWritePost *.py call Flake8() " XXX 这个功能需要安装插件
autocmd FileType python map <buffer> <F12> :call Flake8()<CR>


"
" matchit http://www.vim.org/scripts/script.php?script_id=39
"



"
" vim-go
" https://github.com/fatih/vim-go
" 集成了绝大部分go的开发环境
" 依赖 GOPATH, GOROOT
" 查文档时不会在项目里查，因为不知道项目在哪里呀！
" 所以回去系统默认的函数库中(依赖GOROOT??) 和 GOPATH/src下查询，所以设置好gopath非常重要呀
"
" 有用的命令
" :GoImports 自动import缺失工具
" :GoCallers
" 这个可能有很多可能性，只会列出一种情况(TODO:想想原理是啥，以后别被这个坑才好)
" :GoImplements 找到interface的实现， 和 GoCallers 那几个命令都是依赖于
" oracle的， 但是还不知道怎么用 g:go_oracle_scope 这个参数, 用 下面这个成功过
" let g:go_oracle_scope = 'github.com/GoogleCloudPlatform/kubernetes/cmd/kubectl XXXX'
" 但是非常的慢
au FileType go nmap <Leader>gd <Plug>(go-doc)



"
" TComment
" https://github.com/tomtom/tcomment_vim
" gc 确定一切


"
" vim-slime  &  vim-ipython-cell
" https://github.com/jpalardy/vim-slime
" NOTICE: slime代表着一种边写脚本边搞bash的习惯！一种新的思维方式
" ":i.j" means the ith window, jth pane
" C-c, C-c  --- the same as slime
" C-c, v    --- mnemonic: "variables"
let g:slime_target = "tmux"
" 这个一定要和ipython一起用，否则可能出现换行出问题
let g:slime_python_ipython = 1
" TODO: fix the toggle


" always send text to the pane in the current tmux tab without asking
let g:slime_default_config = {
            \ 'socket_name': get(split($TMUX, ','), 0),
            \ 'target_pane': '{top-right}' }
let g:slime_dont_ask_default = 1

"------------------------------------------------------------------------------
" ipython-cell configuration
"------------------------------------------------------------------------------
" Keyboard mappings. <Leader> is \ (backslash) by default

let g:which_key_map['p'] = {
    \ 'name' : 'IPython Cell',
    \'r' : ['IPythonCellRun', 'IPythonCellRun'],
    \'R' : ['IPythonCellRunTime', 'IPythonCellRunTime'],
    \'e' : ['IPythonCellExecuteCellVerbose', 'Execute Cell'],
    \'E' : ['IPythonCellExecuteCellVerboseJump', 'Execute Cell Jump'],
    \'l' : ['IPythonCellClear', 'IPythonCellClear'],
    \'x' : ['IPythonCellClose', 'IPythonCellClose'],
    \'c' : [':SlimeSend', 'Send line or selected'],
    \'p' : ['IPythonCellPrevCommand', 'Previous Command'],
    \'Q' : ['IPythonCellRestart', 'restart ipython'],
    \'d' : [':SlimeSend1 %debug', 'debug mode'],
    \'t' : [':SlimeSend1 %load_ext autotime', 'debug mode'],
    \'q' : [':SlimeSend1 exit', 'exit'],
    \'k' : ['IPythonCellPrevCell', 'Prev Cell'],
    \'j' : ['IPythonCellNextCell', 'Next Cell']
    \ }
" \'s' : [':SlimeSend1 ipython --matplotlib', 'start ipython with matplotlib'],
" \'b' : ['SlimeSend0 "b ".expand("%:p").":".line("$")', 'Send file break point'],

nnoremap <leader>psb :SlimeSend0 "b ".expand("%:p").":".line(".")."\n"<CR>

" TODO: Combine the ipython cel and jupyter-vim
" - https://vi.stackexchange.com/a/18946



"
" vim-airline
let g:airline#extensions#tabline#enabled = 1
" vim-airline-themes
let g:airline_theme='dark'


"
" heavenshell/vim-pydocstring
" 已经被  doge 淘汰了
" Docstring的详细格式解析: https://stackoverflow.com/a/24385103
" nnoremap <silent> <leader>d <Plug>(pydocstring)
" nnoremap <silent> <leader>d :Pydocstring<cr>
" vnoremap <silent> <leader>d :Pydocstring<cr>
" let g:pydocstring_formatter='numpy'
" FAQ:
" 如果你安装nvim的Python环境和后续Python环境不一样，可能还是得手动安装一下
" pip install doq
"


" BEGIN for coc ----------------------------------------------------------
" if hidden is not set, TextEdit might fail.
set hidden

" Some servers have issues with backup files, see #649
set nobackup
set nowritebackup

" Better display for messages
set cmdheight=2

" You will have bad experience for diagnostic messages when it's default 4000.
set updatetime=300

" don't give |ins-completion-menu| messages.
set shortmess+=c

" always show signcolumns
set signcolumn=yes

" disable python2 provider
let g:loaded_python_provider=0

" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" Use `[c` and `]c` to navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
\:silent! call repeat#set("\<Plug>(coc-diagnostic-prev)", v:count)<CR>
nmap <silent> ]c <Plug>(coc-diagnostic-next)
\:silent! call repeat#set("\<Plug>(coc-diagnostic-next)", v:count)<CR>

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
xmap <leader>cf  <Plug>(coc-format-selected)
nmap <leader>cf  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" # 这个地方可以和coc-snippet结合起来用,  直接将选中的code转化为 snippet
" Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
xmap <leader>cas  <Plug>(coc-codeaction-selected)
nmap <leader>cas  <Plug>(coc-codeaction-selected)

" Remap for do codeAction of current line
nmap <leader>cac  <Plug>(coc-codeaction)

" Fix autofix problem of current line
nmap <leader>cqf  <Plug>(coc-fix-current)

" Use <tab> for select selections ranges, needs server support, like: coc-tsserver, coc-python
nmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <S-TAB> <Plug>(coc-range-select-backword)

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')

" Use `:Fold` to fold current buffer
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" use `:OR` for organize import of current buffer
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Add status line support, for integration with other plugin, checkout `:h coc-status`
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Using CocList
" Show all diagnostics
nnoremap <silent> <space>la  :<C-u>CocList diagnostics<cr>
" Manage extensions
" nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show list comands
nnoremap <silent> <space>ll  :<C-u>CocList<cr>
" Show list vim comands
nnoremap <silent> <space>lv  :<C-u>CocList vimcommands<cr>

" ctags的默认参数是这个
" config/coc/extensions/node_modules/coc-python/resources/ctagOptions
" --extras参数出问题要么改参数成 extra，要么装能兼容版本的ctags deploy_apps/install_ctags.sh
" 如果太慢了，可以用 --verbose debug看看慢在哪里，可以在ctagOptions里面加上exclude
" 但是必须用恰好是文件夹名字，不然无法跳过,  --exclude=mlruns --exclude=models
" Find symbol of current document
nnoremap <silent> <space>lO  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>ls  :<C-u>CocList -I symbols<cr>

" Do default action for next item.
nnoremap <silent> <space>lj  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>lk  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>lp  :<C-u>CocListResume<CR>

" TODO: 这个应该会被 fzf 代替
nnoremap <silent> <Leader>gc :exe 'CocList -I --input='.expand('<cword>').' grep --ignore-case'<CR>
nnoremap <silent> <Leader>gr :exe 'CocList -I grep --ignore-case'<CR>


" TODO: 上面的一堆命令终究将纳入到下面的 which_key_map 中
let g:which_key_map['l'] = {
    \ 'name' : 'coc-list',
    \'o' : [':CocList -I --auto-preview --ignore-case --input=outlines lines', 'Outlines'],
    \'i' : [':CocList -I --auto-preview --ignore-case lines', 'Search in this file'],
    \'c' : [':CocList commands', 'commands'],
    \ }


" scroll the popup
" comes from https://github.com/neoclide/coc.nvim/issues/1405
" I think this is still experimental
function! s:coc_float_scroll(forward) abort
  let float = coc#util#get_float()
  if !float | return '' | endif
  let buf = nvim_win_get_buf(float)
  let buf_height = nvim_buf_line_count(buf)
  let win_height = nvim_win_get_height(float)
  if buf_height < win_height | return '' | endif
  let pos = nvim_win_get_cursor(float)
  if a:forward
    if pos[0] == 1
      let pos[0] += 3 * win_height / 4
    elseif pos[0] + win_height / 2 + 1 < buf_height
      let pos[0] += win_height / 2 + 1
    endif
    let pos[0] = pos[0] < buf_height ? pos[0] : buf_height
  else
    if pos[0] == buf_height
      let pos[0] -= 3 * win_height / 4
    elseif pos[0] - win_height / 2 + 1  > 1
      let pos[0] -= win_height / 2 + 1
    endif
    let pos[0] = pos[0] > 1 ? pos[0] : 1
  endif
  call nvim_win_set_cursor(float, pos)
  return ''
endfunction

nnoremap <silent><expr> <down> coc#util#has_float() ? coc#util#float_scroll(1) : "\<down>"
nnoremap <silent><expr> <up> coc#util#has_float() ? coc#util#float_scroll(0) : "\<up>"
inoremap <silent><expr> <down> coc#util#has_float() ? <SID>coc_float_scroll(1) : "\<down>"
inoremap <silent><expr> <up> coc#util#has_float() ? <SID>coc_float_scroll(0) : "\<up>"
vnoremap <silent><expr> <down> coc#util#has_float() ? <SID>coc_float_scroll(1) : "\<down>"
vnoremap <silent><expr> <up> coc#util#has_float() ? <SID>coc_float_scroll(0) : "\<up>"


let g:coc_global_extensions = [
 \ "coc-python",
 \ "coc-highlight",
 \ "coc-lists",
 \ "coc-json",
 \ "coc-explorer",
 \ "coc-snippets",
 \ "coc-marketplace",
 \ "coc-sh",
 \ "coc-java",
 \ "coc-java-debug",
 \ "coc-marketplace"
 \ ]

" 个人经验 <space>c  setLinter ，把pylama 设置成错误提示的工具方便


" coc-python -------------------
" 如果想用black，那么可以尝试 CocLocalConfig中加入这个
" "python.formatting.provider": "black"
" python.execInTerminal 还是比较好用的



" coc-explorer -------------------
let g:coc_explorer_global_presets = {
\   '.vim': {
\      'root-uri': '~/.vim',
\   },
\   'floating': {
\      'position': 'floating',
\   },
\   'floatingLeftside': {
\      'position': 'floating',
\      'floating-position': 'left-center',
\      'floating-width': 50,
\   },
\   'floatingRightside': {
\      'position': 'floating',
\      'floating-position': 'right-center',
\      'floating-width': 50,
\   },
\   'simplify': {
\     'file.child.template': '[selection | clip | 1] [indent][icon | 1] [filename omitCenter 1]'
\   }
\ }

" Use preset argument to open it
let g:which_key_map['e'] = {
    \ 'name' : 'coc-list',
    \'f' : [':CocCommand explorer --sources=buffer+,file+ --preset floatingRightside', 'Float Explorer'],
    \'c' : [':CocCommand explorer --sources=buffer+,file+', 'Side Explorer'],
    \'e' : [':CocCommand explorer --sources=buffer+,file+ --preset floating', 'Full Explorer'],
    \ }

" List all presets
" nmap <leader>el :CocList explPresets

" BUG
" 有tagbar(或许是别的窗口)的时候，coc-explorer  打开文件会有问题



" coc-snippet ------------------------
" Use <C-l> for trigger snippet expand.
imap <C-l> <Plug>(coc-snippets-expand)

" Use <C-j> for select text for visual placeholder of snippet.
vmap <C-j> <Plug>(coc-snippets-select)

" Use <C-j> for jump to next placeholder, it's default of coc.nvim
let g:coc_snippet_next = '<c-j>'

" Use <C-k> for jump to previous placeholder, it's default of coc.nvim
let g:coc_snippet_prev = '<c-k>'

" Use <C-j> for both expand and jump (make expand higher priority.)
imap <C-j> <Plug>(coc-snippets-expand-jump)


" coc-list ------------------------------
" 这里感觉和文档写的不太一样
" - 默认 list.source.files.command 用 rg
" - 默认参数是 ["--color", "never", "--files"]
" - 所以要做修改需在这些默认值之后操作
"    - 比如想要follow the link就得这么操作: list.source.files.args": ["-L", "--color", "never", "--files"]
"    - https://github.com/neoclide/coc-lists/issues/69
" - NOTE: rg的默认会读入.gitignore
" - 对于floating window的看法: https://github.com/neoclide/coc-lists/issues/61
" 未来有可能的代替品
" - https://github.com/liuchengxu/vim-clap


" coc java 相关 ------------------------
"
" coc-java 一直启动失败[java exited with code: 13](https://github.com/neoclide/coc-java/issues/20)
" 设置 "java.home":
" 

" coc-java不能识别classpath
" 1)
" https://github.com/neoclide/coc-java/issues/93
" 项目目录下的  .classpath 可以修复这个问题
" -       <classpathentry combineaccessrules="false" kind="src" path="/jpf-core"/>
" +       <classpathentry combineaccessrules="false" exported="true" kind="src" path="/jpf-core"/>
" +       <classpathentry kind="lib" path="/home/zhenyue/Develops/jpf/jpf-core/build/jpf.jar"/>
" 2) 如果用的是gradle, `java.import.gradle.enabled": true,` 可能就能使之生效

" coc-java-debug minimal setting
" - 安装: coc-java-debug,  Vimspector, 在项目中配置`.vimspector.json`(配置见项目页)
" - vimspector快捷键设置， 启动java时加参数 -Xdebug -Xrunjdwp:server=y,transport=dt_socket,address=5005,suspend=y 
" - vimspector设置断点， 通过 <leader>lc java.debug.vimspector.start 链接jvm




" DEBUG相关
" 当出现下面情况都先确认环境有没有弄错
" - 解析pylama解析包失败时(找不到包, 比如import时提示无法解析)
" - 做代码跳转时，提示版本太老
" <space>c -> python.setInterpreter 
" 如果上述命令出错了，很可能是python插件没有加载:  <space>e 来加载插件
" 会频繁出现上面问题的原因是它会因为新项目不知道default interpreter是什么
" - https://github.com/neoclide/coc-python/issues/55
"
" Jedi error: Cannot call write after a stream was destroyed
" 包括其他的错误，只要错误信息中涉及到了jedi，更新jedi常常都有用
" pip search jedi, 看看你安装的是不是最新版
" 
" 如果出现运行特别慢的情况，那么可能是因为数据和代码存在一起了,
" 数据小文件特别多，建议把数据单独放到外面。不然得一个一个插件单独地配置XXX_ignore
"
" 如果pylint import找不到module: 是因为pylint无法解析sys.path.append语句
" 1) 可以在 `${workspaceFolder}/.env` 中直接设置`PYTHONPATH`
" - https://github.com/neoclide/coc-python
" - https://code.visualstudio.com/docs/python/environments#_use-of-the-pythonpath-variable
" 2) 用 python setup.py develop
"
" Coc does not install extension if file with same name exists
" 当 ~/.config/coc/ 这个文件在nfs上的时候，会出现所有插件都变成单文件的问题；
" 解决方法1)
" 1. sudo mkdir /mnt/xiaoyang && sudo chown xiaoyang: /mnt/xiaoyang  && mv ~/.config/coc/ /mnt/xiaoyang &&  cd ~/.config &&  && ln -s /mnt/xiaoyang/coc .
" 2. 更新coc文件
" 3. cd ~/.config && unlink coc && sudo mv /mnt/xiaoyang/coc .
" 解决方法2)
" mkdir ~/.config/coc/extensions/node_modules/coc-marketplace/ 后再创建插件


" 各种配置通过这里来设置 
" 直接编辑 ~/.config/nvim/coc-settings.json 或者  CocConfig
" 每个插件的所有配置都可以通过插件项目中的 `package.json` 来找到
" 注意事项
" - 很多类似于  "python.formatting.yapfArgs" ("type": "array")的选项，
"   你要想想它执行的时候类似于subprocess的shell=False, 你的"'{}'"可能会出错


" 还不能解决的问题



" 好用的地方:  grep, gr; 看上面的定义，IDE常用的地方上面都有


" END   for coc ----------------------------------------------------------



" BEGIN for vim-indent-guides ----------------------------------------------------------
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
" END   for vim-indent-guides ----------------------------------------------------------


" 'vim-ctrlspace/vim-ctrlspace'
set nocompatible
set hidden
set encoding=utf-8
hi link CtrlSpaceNormal   PMenu
hi link CtrlSpaceSelected PMenuSel
hi link CtrlSpaceSearch   Search
hi link CtrlSpaceStatus   StatusLine
" visual mode is not useful for me at all
nnoremap <silent>Q :CtrlSpace<CR>
" set showtabline=0
" 好用的: 
" - l可以快速列出所有的tab级别的内容
" 坑:
" - workspace进去默认是一个向上的箭头，表示load;
"   按下s后，会变成向下的箭头代表save，箭头非常不明显
" - 想disable 文件搜索，但是一直没有成功
"   - let g:CtrlSpaceIgnoredFiles = '*'
"   - let g:CtrlSpaceGlobCommand = 'echo "disabled"'



" BEGIN for mhinz/vim-startify ----------------------------------------------------------
let g:ascii_yang = [
      \'____  ________________________  _____________   __________',
      \'__  |/ /___  _/__    |_  __ \ \/ /__    |__  | / /_  ____/',
      \'__    / __  / __  /| |  / / /_  /__  /| |_   |/ /_  / __  ',
      \'_    | __/ /  _  ___ / /_/ /_  / _  ___ |  /|  / / /_/ /  ',
      \'/_/|_| /___/  /_/  |_\____/ /_/  /_/  |_/_/ |_/  \____/   ',
      \]

 let g:ascii_art = [
       \'                           O                                         ',
       \'                                 O           O O                     ',
       \'                                       O     |_|                     ',
       \'                                           <(+ +)>                   ',
       \'                                            ( u )                    ',
       \'                                               \\                    ',
       \'                                                \\                   ',
       \'                                                 \\               )  ',
       \'                                                  \\             /   ',
       \'                                                   \\___________/    ',
       \'                                                   /|          /|    ',
       \'                                                  //||      ( /|| =3 ',
       \'                                                 //-||------//ω||    ',
       \'                                                //  ||     //  ||    ',
       \'                                                \\  ||     \\  ||    ',
       \'                                                /_\ /_\    /_\ /_\   ',
       \]

let g:startify_custom_header =
       \ 'startify#pad(g:ascii_yang + startify#fortune#boxed() + g:ascii_art)'
let g:startify_change_to_dir = 0

let g:startify_lists = [
      \ { 'type': 'dir',       'header': ['   MRU '. getcwd()] },
      \ { 'type': 'files',     'header': ['   MRU']            },
      \ { 'type': 'sessions',  'header': ['   Sessions']       },
      \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      },
      \ { 'type': 'commands',  'header': ['   Commands']       },
      \ ]

" END   for mhinz/vim-startify ----------------------------------------------------------



" BEGIN for 'vim-vdebug/vdebug' ---------------------------------------------------
"
" TODO: 
" 调整mapping, 和 which-key 兼容
" 安装pydbgp:   pip install komodo-python3-dbgp
" 1) :VdebugStart
" 2) pydbgp  -d  localhost:9000 a.py
" END   for 'vim-vdebug/vdebug' ---------------------------------------------------



" jupyter-vim
let g:which_key_map['j'] = {
    \ 'name' : 'jupyter-vim',
    \'e' : ['JupyterSendCell', 'Jupyter Send Cell'],
    \'d' : ['JupyterDisconnect', 'Jupyter Disconnect'],
    \ }
let g:jupyter_mapkeys=0
nmap <leader>jc  :<C-u>JupyterSendCount<CR>
vmap <leader>jc  :<C-u>'<,'>JupyterSendRange<CR>
" 注意只有disconnect之后才能再次connect
nmap <leader>js  :<C-u>JupyterConnect 
nmap <leader>jr  :<C-u>JupyterSendCode 
nmap <leader>jn  <esc>}o<CR># %%<esc>o
nmap <leader>jw  :<C-u>JupyterSendCode expand("<cword>")<CR>
nmap <leader>jl  :<C-u>JupyterSendCode "clear"<CR>
nmap <leader>jp  :<C-u>JupyterSendCode @"<CR>

nmap <Plug>RunCellAndJump <leader>je/# %%<CR>:noh<CR>
\:silent! call repeat#set("\<Plug>RunCellAndJump", v:count)<CR>
nmap <leader>jE <Plug>RunCellAndJump
" 依赖vim-repeat 才能
" config come from http://vimcasts.org/episodes/creating-repeatable-mappings-with-repeat-vim/





" BEGIN 'unblevable/quick-scope' ----------------------------------------------------------
" let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']
let g:qs_buftype_blacklist = ['nofile', 'terminal']  " in case it change the color of some pop text

" END   'unblevable/quick-scope'----------------------------------------------------------



" BEGIN 'jiangmiao/auto-pairs'----------------------------------------------------------
" alt + p 可以控制 pair 的开关
" alt + e 可以在将行中间补全的括号自动放到末尾
" END   'jiangmiao/auto-pairs'----------------------------------------------------------


" BEGIN 'airblade/vim-gitgutter' ------------------------------------------------------
" let g:which_key_map['h'] = {
"     \ 'name' : 'GitGutter(Hank)',
"     \'[' : ['<Plug>(GitGutterPrevHunk)', 'PrevHunk'],
"     \']' : ['<Plug>(GitGutterNextHunk)', 'NextHunk']
"     \ }

nmap <silent> <leader>h[ <Plug>(GitGutterPrevHunk)
\:silent! call repeat#set("\<Plug>(GitGutterPrevHunk)", v:count)<CR>

nmap <silent> <leader>h] <Plug>(GitGutterNextHunk)
\:silent! call repeat#set("\<Plug>(GitGutterNextHunk)", v:count)<CR>

" END   'airblade/vim-gitgutter' ------------------------------------------------------


" BEGIN 'wellle/context.vim' ------------------------------------------------------
let g:context_enabled = 1

" 和neovim一起这样用会有bug
" https://github.com/wellle/context.vim/issues/23
let g:context_nvim_no_redraw = 1 

" 和 vimspector 一起用会出现之前的context留下残影的问题
" :ContextToggle  可以解决这个问题(似乎也没有解决...)

" END   'wellle/context.vim' ------------------------------------------------------


" BEGIN  'machakann/vim-sandwich' -----------------------------------------
" 命令格式
" - {operator}{text obj selection}{surrounding}
" - 如果处于 visual-mode下，{text obj selection} 不用选择
" {operator}: 加了 sa sr sd， 用起来和 d v 之类的operator等价
" {text obj selection}: iw, aw 之类的都可以用
" {surrounding}
" - b变成了surrouding的通配符，之前的 di" , da' 之类的都可以变成 dab
" - 最后输入surronding时， i可以输入复杂的， t可以输入tag
" END    'machakann/vim-sandwich' -----------------------------------------



" BEGIN  'puremourning/vimspector' -----------------------------------------
let g:which_key_map['v'] = {
    \ 'name' : 'vimspector',
    \'c' : ['vimspector#Continue()', 'continue'],
    \'C' : ['vimspector#ClearBreakpoints()', 'clear all breakpoints'],
    \'S' : ['vimspector#Stop()', 'stop'],
    \'p' : ['vimspector#Pause()', 'pause'],
    \'b' : ['vimspector#ToggleBreakpoint()', 'breakpoint toggle'],
    \'o' : ['vimspector#StepOver()', 'step over'],
    \'i' : ['vimspector#StepInto()', 'step into'],
    \'O' : ['vimspector#StepOut()', 'step out'],
    \ }
nnoremap <leader>vB  :call vimspector#ToggleBreakpoint({'condition':''})<left><left><left>
" END    'puremourning/vimspector' -----------------------------------------





" BEGIN  'kana/vim-submode' -----------------------------------------

" :help window-resize
" 来自这里:
" https://ddrscott.github.io/blog/2016/making-a-window-submode/

" A message will appear in the message line when you're in a submode
" and stay there until the mode has existed.
let g:submode_always_show_submode = 1
let g:submode_timeoutlen = 1000

" We're taking over the default <C-w> setting. Don't worry we'll do
" our best to put back the default functionality.
call submode#enter_with('window', 'n', '', '<C-w>')

" Note: <C-c> will also get you out to the mode without this mapping.
" Note: <C-[> also behaves as <ESC>
call submode#leave_with('window', 'n', '', '<ESC>')

" Go through every letter
for key in ['a','b','c','d','e','f','g','h','i','j','k','l','m',
\           'n','o','p','q','r','s','t','u','v','w','x','y','z']
  " maps lowercase, uppercase and <C-key>
  call submode#map('window', 'n', '', key, '<C-w>' . key)
  call submode#map('window', 'n', '', toupper(key), '<C-w>' . toupper(key))
  call submode#map('window', 'n', '', '<C-' . key . '>', '<C-w>' . '<C-'.key . '>')
endfor

" Go through symbols. Sadly, '|', not supported in submode plugin.
" '|' can be achieve ":vertical res"
for key in ['=','_','+','-','<','>']
  call submode#map('window', 'n', '', key, '<C-w>' . key)
endfor

" END    'kana/vim-submode' -----------------------------------------




" BEGIN 'mg979/vim-visual-multi' -----------------------------------------
" 不记得了就多复习 vim -Nu ~/.vim/plugged/vim-visual-multi/tutorialrc
"
" 反vimer直觉的
" <c-v> 才是那个每行都有差异的粘贴， p会粘贴一样的东西
" v选择编辑的操作会出错，得用extend模式代替v
" s不是删除然后立马插入，而是进入到一个selecting模式
" 选取了多行后 \\c 可以创建多个normal模式的光标，\\a可以创建多个extend模式的光标
"
" 优势
" - 和用macro记录改一波再应用到别的位置作对比，
"   用我可以同时看到改这些是怎么变化的
" - 快速替换一些word和标点
" - 将一堆赋值替换成 tuple
"
" BUG
" - 后来好像 <C-v> <C-up>等等ctrl开头的功能好像不管用了。。。后面发现是tmux的问题
"
" END   'mg979/vim-visual-multi' -----------------------------------------



" BEGIN 'junegunn/fzf.vim' -----------------------------------------
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.8 } }

" https://github.com/junegunn/fzf.vim/issues/346
" not include the name of the file
command! -bang -nargs=* Agc call fzf#vim#ag(<q-args>, {'options': '--delimiter : --nth 4..'}, <bang>0)

nnoremap <silent> <Leader>fc :exe 'Ag '.expand('<cword>')<CR>
" No name
nnoremap <silent> <Leader>fCn :exe 'Agc '.expand('<cword>')<CR>
nnoremap <silent> <Leader>fCl :exe 'BLines '.expand('<cword>')<CR>
nnoremap <silent> <Leader>fCL :exe 'Lines '.expand('<cword>')<CR>
inoremap <expr> <c-x><c-f> fzf#vim#complete#path('fd')

let g:which_key_map['f'] = {
    \ 'name' : 'fzf',
    \'g' : ['Ag', 'Ag'],
    \'G' : ['Agc', 'Ag without filename'],
    \'l' : ['BLines', 'Lines in the current buffer'],
    \'L' : ['Lines', 'Lines in loaded buffer'],
    \'m' : ['Marks', 'Marks'],
    \'o' : [':Lines Outlines', 'Outlines']
    \ }
" 这里可以通过tab选多个，回车后变成quick fix
" END   'junegunn/fzf.vim' -----------------------------------------


" BEGIN 'kkoomen/vim-doge' -----------------------------------------
let g:doge_doc_standard_python = 'numpy'
" END   'kkoomen/vim-doge' -----------------------------------------



" Nvim usage cheetsheet

" 目录
" - 设计理念
" - 查看当前设置
" - Moving
" - Mode相关
" - experssion
" - 其他
" - 坑
" - script
" - 其他可能有用的插件
" - TODO


" ========== 设计理念 ==========
" buffer, window, tab的设计理念
" A buffer is the in-memory text of a file
" A window is a viewport on a buffer.
" A tab page is a collection of windows.
" 所以之前每次开tab而不是buffer，感觉tagbar和nerdtree总是要重复打开很烦;

" map的设计逻辑; 各种map的区别
" - 有没有re代表会不会map后再次被map
" - 前缀代表它在什么模式下生效
" - 它可以映射成一段直接输入，也能映射成一个将会被解析成字符串的表达式
"   - :help <expr>  " 如果想让map映射到一个可解释的字符串


" ========== 查看当前设置 ==========
" global settings
" 检查按键到底被映射成什么了
" :verbose nmap <CR>


" ========== Moving ==========
" Moving: http://vimdoc.sourceforge.net/htmldoc/motion.html
" # Text object selection: 在v或者operation之后 指定文本范围
" help diw daw 等等


" ========= Mode相关 =========
" Command line mode or insert mode:
" 可以直接 <C-R><寄存器>, 插入寄存器的内容
" https://vim.fandom.com/wiki/Pasting_registers


" ========= Expression =========
" echo expand("%:p").":".line("$")


" ========== 其他 ==========
" 匹配: 正向预查，反向预查，环视


" ========== 坑 ==========
" terminal mode 可以解决终端乱码的问题， 还可以用  <c-\><c-n> 和 i 在normal
" model 和terminal model之间切换
"
" CocInstall 会产生空的文件
" https://github.com/neoclide/coc.nvim/issues/2010
"
" ctrlspace load workspace非常慢
" https://github.com/vim-ctrlspace/vim-ctrlspace/issues/6


" ========== 其他可能有用的插件 ==========
" git blame: https://github.com/APZelos/blamer.nvim
" FZF Redo: https://github.com/junegunn/fzf.vim/pull/941


" ========== script ==========
" vim script cheatsheet https://devhints.io/vimscript
" help script



" ========== TODO ==========
" Highlight 整行
" - https://vi.stackexchange.com/questions/15505/highlight-whole-todo-comment-line
" - https://stackoverflow.com/questions/2150220/how-do-i-make-vim-syntax-highlight-a-whole-line



" other cheetsheet
" deploy_apps/install_neovim.sh
