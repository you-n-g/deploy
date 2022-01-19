call plug#begin('~/.vim/plugged')
" cspell:disable
Plug 'scrooloose/nerdtree'
Plug 'majutsushi/tagbar'  " 这个升级后就出错了
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

" 这里需要依赖 https://github.com/ryanoasis/nerd-fonts, 需要在本地安装字体, DejaVu(favorite)
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'mhinz/vim-startify'
" Plug 'vim-ctrlspace/vim-ctrlspace'
" Plug 'liuchengxu/vim-which-key'  这个插件有问题， 和context冲突,
" 如果第一次按没有触发， 第二次再按空着就会出错
Plug 'folke/which-key.nvim'  " 这个修复了 vim-which-key 的问题

" Plug 'vim-vdebug/vdebug'   " 等待确认这个插件没有问题,
" 希望这个插件可以代替vscode

" Plug 'wellle/tmux-complete.vim'
" 好是好
" - 但是我tmux窗口太多了，会引起性能问题
"   后来发现这个参数 `"scrollback':      0,`,  不会追溯到历史，所以性能问题也不严重
" - 而且会影响其他snippets的选择
" TODO: 是不是有可能只包含同个window的tmux信息

Plug 'jpalardy/vim-slime' " , { 'for': 'python' } 加上这个之后会导致只对python有用
Plug 'hanschen/vim-ipython-cell', { 'for': 'python' }

Plug 'jupyter-vim/jupyter-vim'
Plug 'goerz/jupytext.vim' " `pip install jupytext` is required
" let g:jupytext_enable = 0  " to disable jupytext. I tried, but it does not work
" 这个能使用需要你能对你阅读的目录有写权限（因为jupytext会往目录下新写一个文件）

Plug 'unblevable/quick-scope'
Plug 'tpope/vim-repeat'
Plug 'jiangmiao/auto-pairs'
Plug 'kshenoy/vim-signature'
Plug 'airblade/vim-gitgutter'

" Plug 'wellle/context.vim'  "  被tree  sitter 替代了

Plug 'machakann/vim-sandwich'

Plug 'ludovicchabant/vim-gutentags'  " 自动生成更新ctags
" tags围绕tag stack进行,  ctrl+t pop操作， ctrl+] push操作(如果找得到顺便jump一下)

Plug 'puremourning/vimspector'
Plug 'kana/vim-submode'

" NOTE: 还没看具体教程
" Plug 'terryma/vim-multiple-cursors'
Plug 'mg979/vim-visual-multi'

Plug 'kkoomen/vim-doge', { 'do': { -> doge#install() } }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'APZelos/blamer.nvim'
Plug 'easymotion/vim-easymotion'
" Plug 'sslivkoff/vim-scroll-barnacle'
" - 后来发现这个可以解决这个问题: https://github.com/wfxr/minimap.vim
Plug 'psliwka/vim-smoothie'
Plug 'pevhall/simple_highlighting'
Plug 'AndrewRadev/sideways.vim'
Plug 'szw/vim-maximizer'
" Plug 'camspiers/lens.vim'  " TODO: toggle function https://stackoverflow.com/a/20579322

" https://github.com/numirias/semshi/issues/60
" - 如果报错 'Unknown function: SemshiBufWipeout' ， 记得运行 :UpdateRemotePlugins
Plug 'numirias/semshi', {'do': ':UpdateRemotePlugins'}

" Treesitter 里面有很多插件似乎很棒
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'romgrk/nvim-treesitter-context'  " treesitter dependent
Plug 'p00f/nvim-ts-rainbow'  " treesitter dependent

Plug 'tpope/vim-fugitive'


" 这边是为了给 coc-snippets 提供文件支持
" Track the engine.
Plug 'SirVer/ultisnips'
" Snippets are separated from the engine. Add this if you want them:
Plug 'honza/vim-snippets'

" Plug 'junegunn/vim-peekaboo'  " 看剪切板非常方便:  但是常常会造成我的电脑卡死。。。 不知为何
" Plug 'tversteeg/registers.nvim', { 'branch': 'main' }   " 第二个看register的插件,  但是这个和 which_key 功能一样， 所以先不用了

Plug 'voldikss/vim-translator'


Plug 'akinsho/toggleterm.nvim'
" - 试用的困难请在 yx_conf 中查找


" Plug 'untitled-ai/jupyter_ascending.vim'
" 这种模式我非常喜欢，但是现在还有不足的地方
" - 它运行cell的时候感觉位置不对, 等待这个错误的解决
"   https://github.com/untitled-ai/jupyter_ascending.vim/issues/8


" just for help tags
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

Plug 'neovim/nvim-lspconfig'
Plug 'nvim-treesitter/playground' " treesitter dependent

" Dev lua
" Plug 'tjdevries/nlua.nvim'  "  this seems  require builtin lsp
Plug 'bfredl/nvim-luadev'
call plug#end()

" cspell:enable

" settings -------------------------


" Neovim有的缺陷:
" - encoding似乎只能设置utf8, 对其他encoding支持没有那么好


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

" examples to ignore
" ignore a directory on top level
" let g:NERDTreeIgnore += ['^models$']
" let g:ctrlp_custom_ignore = {
"   \ 'dir':  '\vmodels$',
"   \ }

" coc-lists 和 fzf 相关的都是用 ag, fd 之类的命令， 他们都识别 .ignore (不是git仓库也行) 和 .gitignore (前提是这是个git仓库)
" .ignore 要写全路径才行，不能只写一个文件名

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

let g:gruvbox_contrast_dark="hard"
" let g:gruvbox_contrast_dark="soft"
set background=dark
colorscheme gruvbox


" inoremap <Esc> <NOP>
" noremap <Esc> <NOP>
" " TODO: This will make `ctrl+[` disabled.


" customized functions

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
        autocmd FileType python,sh,zsh hi Outlines1 cterm=bold ctermbg=017 ctermfg=White
        autocmd FileType python,sh,zsh hi Outlines2 cterm=bold ctermbg=019 ctermfg=White
        autocmd FileType python,sh,zsh hi cellDelimiterHi ctermbg=233 ctermfg=DarkGray
    else
        autocmd FileType python,sh,zsh hi Outlines1 cterm=bold ctermbg=darkblue ctermfg=White
        autocmd FileType python,sh,zsh hi Outlines2 cterm=bold ctermbg=blue ctermfg=White
        autocmd FileType python,sh,zsh hi cellDelimiterHi ctermbg=Black ctermfg=DarkGray
    endif

    autocmd FileType python,sh,zsh sign define cellLine linehl=cellDelimiterHi
    autocmd FileType python,sh,zsh sign define O1 linehl=Outlines1
    autocmd FileType python,sh,zsh sign define O2 linehl=Outlines2

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
    au TextYankPost * silent! lua vim.highlight.on_yank{higroup="IncSearch", timeout=700}
augroup END

"
" The plugins I always need -------------------------
" https://github.com/neovim/neovim/wiki/Related-projects#plugins
"

" Plug 'liuchengxu/vim-which-key'
" & WhichKey
" I should before any key define based on vim-which-key

set timeoutlen=500 " By default timeoutlen is 1000 ms


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
" 据说可以管理vimwiki的backlinks
" https://github.com/michal-h21/vim-zettel



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
" highlight TagbarHighlight ctermfg=17 ctermbg=190 guifg=#00005f guibg=#dfff00
highlight link TagbarHighlight Cursor

" For config
let g:tagbar_position="topleft vertical"



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


" BEGIN for vim-slime  &  vim-ipython-cell --------------------------------
" vim-slime  &  vim-ipython-cell
" https://github.com/jpalardy/vim-slime
" NOTICE: slime代表着一种边写脚本边搞bash的习惯！一种新的思维方式
" ":i.j" means the ith window, jth pane
" C-c, C-c  --- the same as slime
" C-c, v    --- mnemonic: "variables"

" let g:slime_target = "tmux"
" " These lines must be deleted if we use "neovim" slime_target
" " always send text to the pane in the current tmux tab without asking
" let g:slime_default_config = {
"             \ 'socket_name': get(split($TMUX, ','), 0),
"             \ 'target_pane': '{top-right}' }
" let g:slime_dont_ask_default = 1

let g:slime_target = "neovim"

" pro:
" - 这里如果能换成 neovim 的话， 会更方便 (navigate更方便,
"   而且颜色高亮等等功能还可以临时加)
" - 而且 速度比 tmux 快很多!!!!
" - 可以用vim直接看结果，能方便地在不同的文件中跳转
" con:
" - neovim有时候不稳定， 会导致 terminal也一起出错;
"   建议要稳定性的话，就走路线
"   可能先把其他关掉，留下这个terminal比较合适
" TODO:
" - 这里如果能自动选择 terminal的话就比较爽了
"   - 只有一个terminal时， 会自动选择
"   - echo &channel
" 发现的高效的习惯
" - 这玩意不能像 tmux 那样swap时还保留 布局的窗口大小 ,
"   它保留的是本身的窗口大小; 所以 ctrl + 6 来切换
"   terminal和code也是一个不错的选择
"
"
" 这个一定要和ipython一起用，否则可能出现换行出问题
let g:slime_python_ipython = 1

" clear previous command
nnoremap <c-c><c-u> :SlimeSend0 "\x15"<CR>
" Interupted command
nnoremap <c-c><c-i> :SlimeSend0 "\x03"<CR>
" ^D	EOT	004	04	End of Transmission
nnoremap <c-c><c-d> :SlimeSend0 "\x04"<CR>
" `esc` `k`  `carriage return`
nnoremap <c-c><c-p> :SlimeSend0 "\x1bk\x0d"<CR>
" TODO: 发现无法把 ctrl+arrow 之类的操作符send 过去


" TODOs
" TODO: fix the toggle
" let g:slime_target = "neovim"  " 这个也支持哦


if get(g:, "slime_target", "") == "neovim"
  augroup auto_channel
    autocmd!
    " autocmd TermEnter * let g:slime_last_channel = &channel
    autocmd BufEnter * lua require"slime".reset_slime()
  augroup END
end


" DEBUG & FAQ
" 如果发现发送过去的内容不是选中的内容，可以看看你是不是开了 vi-mode
" 之前创建过一个环境，vim-slime没有用， 目前怀疑是 python 3.9的问题
" vim-slime 需要依赖 tmux 配置对(即`where tmux`可以找到正确的结果);
" - 具体卡死的命令: `tmux -S /tmp/tmux-1003/default load-buffer /data1/<user>/home/.slime_paste`
" - 解决方法见tmux安装的脚本

" END   for vim-slime  &  vim-ipython-cell --------------------------------



"------------------------------------------------------------------------------
" ipython-cell configuration
"------------------------------------------------------------------------------
" Keyboard mappings. <Leader> is \ (backslash) by default

" shell related
nnoremap <leader>psr :SlimeSend0 "python ".expand("%:p")."\n"<CR>
nnoremap <leader>psR :SlimeSend0 "python ".expand("%")."\n"<CR>

nnoremap <leader>pSr :SlimeSend0 "python ".expand("%:p")<CR>
nnoremap <leader>pSR :SlimeSend0 "python ".expand("%")<CR>

" 这里有点缺陷，在Python的 docstring的位置不能正确输出结果
" nnoremap <leader>psf :SlimeSend0 "python ".expand("%:p")." ".luaeval('require("run_func").get_current_function_name()')."\n"<CR>
" nnoremap <leader>psF :SlimeSend0 "python ".expand("%")." ".luaeval('require("run_func").get_current_function_name()')."\n"<CR>

" nnoremap <leader>pSf :SlimeSend0 "python ".expand("%:p")." ".luaeval('require("run_func").get_current_function_name()')<CR>
" nnoremap <leader>pSF :SlimeSend0 "python ".expand("%")." ".luaeval('require("run_func").get_current_function_name()')<CR>

nnoremap <leader>pss :SlimeSend0 "bash ".expand("%:p")."\n"<CR>

nnoremap <leader>psd :SlimeSend0 "pypdb ".expand("%:p")."\n"<CR>
nnoremap <leader>psD :SlimeSend0 "pypdb ".expand("%")."\n"<CR>
nnoremap <leader>psp :SlimeSend0 "pyprof ".expand("%:p")."\n"<CR>
nnoremap <leader>pskp :SlimeSend0 "kernprof -l ".expand("%:p")."\n"<CR>
nnoremap <leader>pskc :SlimeSend0 "python -m line_profiler ".expand("%:t").".lprof\n"<CR>
" nnoremap <leader>pst :SlimeSend0 "nosetests --nocapture --ipdb --ipdb-failures ".expand("%:p")."\n"<CR>
nnoremap <leader>pst :SlimeSend0 "pytest -s --pdb --disable-warnings ".expand("%:p")."::".luaeval('require("run_func").get_current_function_name(true)')."\n"<CR>

nnoremap <leader>pdb :SlimeSend0 "b ".expand("%:p").":".line(".")."\n"<CR>
nnoremap <leader>pde :SlimeSend1 from IPython import embed; embed()<CR>

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



" BEGIN for vim-indent-guides ----------------------------------------------------------
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
" END   for vim-indent-guides ----------------------------------------------------------


" 'vim-ctrlspace/vim-ctrlspace'
" 本来走的下面的逻辑
" set nocompatible
" set hidden
" set encoding=utf-8
" hi link CtrlSpaceNormal   PMenu
" hi link CtrlSpaceSelected PMenuSel
" hi link CtrlSpaceSearch   Search
" hi link CtrlSpaceStatus   StatusLine
" " visual mode is not useful for me at all
" nnoremap <silent>Q :CtrlSpace<CR>
" nnoremap <silent>Q :Telescope buffers<CR>

lua << EOF
vim.api.nvim_set_keymap('n', 'Q', ":lua require('telescope/buffer').my_buffers()<cr>", {noremap = true})
EOF

" set showtabline=0  " tabline的开关和 vim-airline 的setting得一起修改的
" 好用的:
" - l可以快速列出所有的tab级别的内容
" 用好这个插件需要知道的
" - `?` 可以找到help
" - <cr> 可以找用vim页面单独打开文件， 这样就可以在help中快速索引
" 坑:
" - workspace进去默认是一个向上的箭头，表示load;
"   按下s后，会变成向下的箭头代表save，箭头非常不明显
" - 想disable 文件搜索，但是一直没有成功
"   - let g:CtrlSpaceIgnoredFiles = '*'
"   - let g:CtrlSpaceGlobCommand = 'echo "disabled"'
" - 会影响sesesion的 load 和 save
"   - https://github.com/vim-ctrlspace/vim-ctrlspace/issues/293
"   - https://github.com/vim-ctrlspace/vim-ctrlspace/issues/294



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


" add following to `.nvimrc` to set the code
" let g:gitgutter_diff_base = '<commit SHA>'


" END   'airblade/vim-gitgutter' ------------------------------------------------------

" BEGIN 'tpope/vim-fugitive' ------------------------------------------------------


function! GoParentDir()
  if b:fugitive_type =~# '^\(tree\|blob\)$'
    " execute("e %:h/")
    e %:h
    " 这里还有点问题， 从commit 那里往下走时，第一个blob会被卡住
  endif
endfunction

augroup FugitiveMappings
  autocmd!
  autocmd FileType git nnoremap <buffer>  <BS> :call GoParentDir()<CR>
  " 这里我不太理解为什们不能  autocmd nnoremap if 直接互相嵌套
augroup END


" \ autocmd FileType git
" \ execute("normal G") |
" \ execute(":nnoremap <buffer> <BS> :edit %:h<CR>") |

" autocmd User fugitive
"   \   echom "good" |
" " \   nnoremap <buffer> .. :edit %:h<CR> |

" # 其他有用的
" ## 我还没搞明白它的两种运行机制
" 一种出现quickfix  (Glog)
" ## 在naviage mode下面[疑似]
" 我感觉 navigate 逻辑是这么走的： 从 commit trace -> commmit内容 -> 这个commit内部的文件原文
" - 这些东西都可以在文件中直接打开
"   - tree: commit
"   - +++/--- 文件名
"   - 等等...
" - 下面的命令都可以在这个文件中看到
" p : preview 看看里面是个啥;
" dp: 根据当前光标看看 diff 啥的(到底改了哪里), 可以直接看文件的， 也可以直接看stage的
"
" ## Tips
" g?: 可以快速找到mapping的文档
" CTRL_W+C 控制比较方便(不容易退出vim)
" ## Refs
" - 非常好的教程: http://vimcasts.org/episodes/fugitive-vim-browsing-the-git-object-database/

" END   'tpope/vim-fugitive' ------------------------------------------------------



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
nnoremap <leader>vB  :call vimspector#ToggleBreakpoint({'condition':''})<left><left><left>

" Python DEBUG
" :VimspectorInstall debugpy
" vim .vimspector.json   # 贴上这里的结果就行: https://github.com/puremourning/vimspector#python
"                        # 改几个尖括号里面的内容就行
" 跑 continue就行

" 其他看文档就能知道的信息
" - Exception breakpoints
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
" 复制粘贴
" - 有时候normal模式下x剪切，再<c-v>粘贴会没用; extend模式d删除，然后在<c-v>粘贴我这边能work
" - <c-v> 才是那个每行都有差异的粘贴， p会粘贴一样的东西
" v选择编辑的操作会出错，得用extend模式代替v
" s不是删除然后立马插入，而是进入到一个selecting模式
" 选取了多行后 \\c 可以创建多个normal模式的光标，\\a可以创建多个extend模式的光标
"
" 有用的功能: https://github.com/mg979/vim-visual-multi/blob/master/doc/vm-tutorial
" - 在<c-n>时， \\w 可以切换是否要boundary,  \\c 可以切换是否要 case-sensitive
" - 在visual mode 选择cursor时，m是一个标记操作符， mG 代表从当前标记到结尾
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


" not include the name of the file
" https://github.com/junegunn/fzf.vim/issues/346
" command! -bang -nargs=* Agc call fzf#vim#ag(<q-args>, {'options': '--delimiter : --nth 4..'}, <bang>0)
" 其实这里也说了preview怎么一起用

" 上面的命令发现preview 没用后， 在这里找到了能用的句子:   https://github.com/junegunn/fzf.vim/issues/362
command! -bang -nargs=* Agc call fzf#vim#ag(<q-args>, fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}), <bang>0)
command! -bang -nargs=* Rgc
  \ call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case ".shellescape(<q-args>), 1, fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right', 'ctrl-/'), <bang>0)

" [solution for long lines](https://github.com/junegunn/fzf.vim/issues/1051)
command! -bang -nargs=* Rg
  \ call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case -- ".shellescape(<q-args>), 1, fzf#vim#with_preview('right', 'ctrl-/'), <bang>0)

command! -bang -nargs=* RgPlug
  \ call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case -- ".shellescape(<q-args>), 1, fzf#vim#with_preview({"dir": "~/.vim/plugged/"}), <bang>0)
" - 不能和 right ctrl-/ 兼容

" rg直接跳转到特定代码特定行非常管用!!!!

nnoremap <silent> <Leader>fc :exe 'Rg '.expand('<cword>')<CR>
" FIXME: 这个命令有一个意外的地方是 <cword> 不会搜索名字; 进去之后就算名字了
" No name
nnoremap <silent> <Leader>fCc :exe 'Rgc '.expand('<cword>')<CR>
nnoremap <silent> <Leader>fCl :exe 'BLines '.expand('<cword>')<CR>
nnoremap <silent> <Leader>fCL :exe 'Lines '.expand('<cword>')<CR>
inoremap <expr> <c-x><c-f> fzf#vim#complete#path('fd')
inoremap <expr> <c-x><c-k> fzf#vim#complete('cat ~/.english-words/words_alpha.txt')
imap <c-x><c-l> <plug>(fzf-complete-line)


" 有用的技巧
" Search syntax: https://github.com/junegunn/fzf#search-syntax
" '(exact-match) ^(prefix-exact-match) $(suffix-exact-match) !(inverse-exact-match)  有特殊意义
" - 而且这些还可以连着用！！！！
" 快捷键
" - ^t (open in new tab) ^x(open in horizontal split) ^v (open in vertical split)

" 待解决的问题
" https://github.com/junegunn/fzf.vim/issues/374
" Lines 和 Blines 无法被 preview
" 无法做Outlines: https://github.com/junegunn/fzf.vim/issues/279

" END   'junegunn/fzf.vim' -----------------------------------------


" BEGIN 'kkoomen/vim-doge' -----------------------------------------
let g:doge_doc_standard_python = 'numpy'

" DEBUG:
" 如果没有效果可以强行安装一下:  `:call doge#install()`
" END   'kkoomen/vim-doge' -----------------------------------------


" BEGIN 'APZelos/blamer.nvim' -----------------------------------------
" It is useful when reviewing code
nnoremap <silent> <Leader>tb :BlamerToggle<CR>
let g:blamer_delay = 500
" END   'APZelos/blamer.nvim' -----------------------------------------


" BEGIN 'easymotion/vim-easymotion' -----------------------------------------

" " <Leader>f{char} to move to {char}
" map  <Leader>f <Plug>(easymotion-bd-f)
" nmap <Leader>f <Plug>(easymotion-overwin-f)
"
" " s{char}{char} to move to {char}{char}
" nmap s <Plug>(easymotion-overwin-f2)
"
" " Move to line
" map <Leader>L <Plug>(easymotion-bd-jk)
" nmap <Leader>L <Plug>(easymotion-overwin-line)

" Move to word
map  <Leader>w <Plug>(easymotion-bd-w)
nmap <Leader>w <Plug>(easymotion-overwin-w)

" 优点:
" 可以跳转到任意位置(即使在有多个窗口的情况下)

" END   'easymotion/vim-easymotion' -----------------------------------------


" BEGIN 'sslivkoff/vim-scroll-barnacle' -----------------------------------------
" let g:which_key_map.t.r = ["ScrollbarToggle", 'Scrollbar Toggle']
" highlight ScrollBlockBottom gui=reverse cterm=reverse
" END   'sslivkoff/vim-scroll-barnacle' -----------------------------------------

" BEGIN 'pevhall/simple_highlighting' -----------------------------------------
nmap <Leader>H <Plug>HighlightWordUnderCursor
vmap <Leader>H <Plug>HighlightWordUnderCursor

" 有用的命令
" Ha 3 @
" - *HighlightAddMultiple*
" Hwb
" - *HighlightCommandsBuffer*  注意，这里要求用户现在已经开了一个buffer

" END   'pevhall/simple_highlighting' -----------------------------------------

" BEGIN 'AndrewRadev/sideways.vim' -----------------------------------------
nnoremap <c-h> :SidewaysLeft<cr>
nnoremap <c-l> :SidewaysRight<cr>
" END   'AndrewRadev/sideways.vim' -----------------------------------------


" BEGIN 'camspiers/lens.vim' -----------------------------------------
" TODO: toggle function https://stackoverflow.com/a/20579322

" " let g:lens#height_resize_max = 60
" " let g:lens#width_resize_max = 120
" let g:lens#height_resize_max = winheight('%') / 4 * 3
" let g:lens#width_resize_max = winwidth('%') / 4 * 3
" let g:which_key_map.t.r = ["lens#toggle()", 'lens(resize toggle)']
" let g:lens#disabled_filetypes = ['nerdtree', 'fzf', 'tagbar']

" END   'camspiers/lens.vim' -----------------------------------------



" BEGIN 'numirias/semshi' -----------------------------------------
" This is too noisy when using with  CocActionAsync('highlight')
let g:semshi#mark_selected_nodes=0
" END   'numirias/semshi' -----------------------------------------


" BEGIN 'voldikss/vim-translator' -----------------------------------------
""" Configuration example
" Echo translation in the cmdline
nmap <silent> <Leader>Dt <Plug>Translate
vmap <silent> <Leader>Dt <Plug>TranslateV
" Display translation in a window
nmap <silent> <Leader>Dw <Plug>TranslateW
vmap <silent> <Leader>Dw <Plug>TranslateWV
" Replace the text with translation
nmap <silent> <Leader>Dr <Plug>TranslateR
vmap <silent> <Leader>Dr <Plug>TranslateRV
" Translate the text in clipboard
nmap <silent> <Leader>Dx <Plug>TranslateX
" 因为可以用  ctrl+w 来做， 所以这里就不管了
" nnoremap <silent><expr> <M-f> translator#window#float#has_scroll() ?
"                             \ translator#window#float#scroll(1) : "\<M-f>"
" nnoremap <silent><expr> <M-b> translator#window#float#has_scroll() ?
"                             \ translator#window#float#scroll(0) : "\<M-f>"
" END   'voldikss/vim-translator' -----------------------------------------


" BEGIN 'dhruvasagar/vim-table-mode' --------------------------------------
" 好用的功能
" - :TableSort   # 后面还有一堆参数可以研究一下
" END   'dhruvasagar/vim-table-mode' --------------------------------------


" BEGIN 'nvim-treesitter/nvim-treesitter' ---------------------------------
" The lua part is in yx_conf.lua
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()
set foldlevel=99
" END   'nvim-treesitter/nvim-treesitter' ---------------------------------



" BEGIN 'telescope related' -----------------------------------------
" Mappings https://github.com/nvim-telescope/telescope.nvim#mappings
" <c-q>: 上面还漏了一个， 这个可以用quick fix 打开， 批量修复非常方便
" END   'telescope related' -----------------------------------------


runtime yx_conf/plugins.vim


lua << EOF
require("yx_conf")
EOF


" Nvim usage cheatsheet

" 目录
" - 设计理念
" - 查看当前设置
" - Moving
" - Mode相关
" - experssion
" - 数据类型 & 流程语法
" - 其他
" - 坑
" - script
" - 其他可能有用的插件
" - TODO


" ========== 设计理念/内嵌机制 ==========
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

" autocmd
" autoloading
" command function


" ============ 快捷键 ============
" `@:` : 执行上一个命令; 通过mapping调用的命令不会进入这个, q: 中的命令才会

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

" ===== 数据类型 & 流程语法 =====
" echo ''''   代表 echo "'"

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
" FZF Redo: https://github.com/junegunn/fzf.vim/pull/941
" https://github.com/rhysd/conflict-marker.vim
" https://github.com/romgrk/winteract.vim
" https://github.com/akinsho/toggleterm.nvim
" - 开关terminal更方便
" - terminal的名字更容易理解
" 解决Buffer delete的问题: delete buffer会连带着它相应的 layout 都关掉(比如tab, split等等)，当只有最后一个layout窗口时，它才会保留并只删除buffer
" - https://www.reddit.com/r/vim/comments/jtpluq/close_buffer_but_not_the_window/
" - https://github.com/qpkorr/vim-bufkill
" - https://github.com/moll/vim-bbye
" - 因为手动解决方法好用: ctrl+^ :bd#， 所以一直没有想着用插件;
"   但是它有如下缺陷: 如果 alternative buffer
"   也有一个对应的layout(在另外的tab或者split)，那么这个layout会被删掉
" https://alpha2phi.medium.com/jupyter-notebook-vim-neovim-c2d67d56d563#ba87


" ========== script ==========
" vim script cheatsheet
" - https://devhints.io/vimscript
" - https://github.com/johngrib/vimscript-cheatsheet
" help script

" 内置config在scripts中引用: 类似于 `echo &filetype` 等价于 `set filetype`

" str =~ "<正则表达式，注意\要写成 \\>"


" ========== TODO ==========
" Highlight 整行
" - https://vi.stackexchange.com/questions/15505/highlight-whole-todo-comment-line
" - https://stackoverflow.com/questions/2150220/how-do-i-make-vim-syntax-highlight-a-whole-line
"
" Snippets 其实是有一套自己的语法
" - https://www.jianshu.com/p/c0ba049878ca

" 更好的管理剪切板
" https://github.com/svermeulen/vim-yoink

" 这里的插件可以参考
" https://github.com/Blacksuan19/init.nvim

" 要不要用 nvim-lsp
" 相应的套装
" - https://github.com/hrsh7th/nvim-compe
"       - 优点: spell completion( 后面发现 :CocInstall coc-zi 有相应的功能)

" :changes 可视化
" https://github.com/axlebedev/footprints

" other cheatsheet
" deploy_apps/install_neovim.sh
