" NOTE:
" 未来尽量统一使用lua的 config

" runtime yx/plugs/coc_conf.vim

"
" The plugins I always need -------------------------
"

" Plug 'liuchengxu/vim-which-key'
" & WhichKey
" I should before any key define based on vim-which-key

set timeoutlen=500 " By default timeoutlen is 1000 ms





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
    autocmd BufEnter,WinEnter,TermOpen  * lua require"yx/plugs/slime".reset_slime()
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
nnoremap <leader>psR :SlimeSend0 "python ".expand("%:p")."\n"<CR>
nnoremap <leader>psr :SlimeSend0 "python ".expand("%")."\n"<CR>

nnoremap <leader>pSR :SlimeSend0 "python ".expand("%:p")<CR>
nnoremap <leader>pSr :SlimeSend0 "python ".expand("%")<CR>

" 这里有点缺陷，在Python的 docstring的位置不能正确输出结果
" nnoremap <leader>psf :SlimeSend0 "python ".expand("%:p")." ".luaeval('require("yx/plugs/run_func").get_current_function_name()')."\n"<CR>
" nnoremap <leader>psF :SlimeSend0 "python ".expand("%")." ".luaeval('require("yx/plugs/run_func").get_current_function_name()')."\n"<CR>

" nnoremap <leader>pSf :SlimeSend0 "python ".expand("%:p")." ".luaeval('require("yx/plugs/run_func").get_current_function_name()')<CR>
" nnoremap <leader>pSF :SlimeSend0 "python ".expand("%")." ".luaeval('require("yx/plugs/run_func").get_current_function_name()')<CR>

" nnoremap <leader>pss :SlimeSend0 "bash ".expand("%:p")."\n"<CR>

nnoremap <leader>psD :SlimeSend0 "python -m ipdb -c c ".expand("%:p")."\n"<CR>
nnoremap <leader>psd :SlimeSend0 "python -m ipdb -c c ".expand("%")."\n"<CR>
nnoremap <leader>psp :SlimeSend0 "pyprof ".expand("%:p")."\n"<CR>
nnoremap <leader>pskp :SlimeSend0 "kernprof -l ".expand("%:p")."\n"<CR>
nnoremap <leader>pskc :SlimeSend0 "python -m line_profiler ".expand("%:t").".lprof\n"<CR>
" nnoremap <leader>pst :SlimeSend0 "nosetests --nocapture --ipdb --ipdb-failures ".expand("%:p")."\n"<CR>
nnoremap <leader>pst :SlimeSend0 "pytest -s --pdb --disable-warnings ".expand("%:p")."::".luaeval('require("yx/plugs/run_func").get_current_function_name(true)')."\n"<CR>
lua << EOF
function get_pytest_doctest_module()
    -- often used command let b:ptdm="abc"
    -- - let b:ptdm="abc"
    -- - unlet b:ptdm
    local ok, ptdm = pcall(vim.api.nvim_buf_get_var, 0, "ptdm")
    if ok then
        return ptdm
    end
    return vim.fn.expand("%:t:r")
end
EOF
nnoremap <silent>  <leader>psT :SlimeSend0 "pytest -s --pdb --disable-warnings --doctest-modules ".expand("%:p")."::".luaeval("get_pytest_doctest_module()").".".luaeval('require("yx/plugs/run_func").get_current_function_name(true)')."\n"<CR>
" I don't know why there must be module name before function name when
" calling pytest (i.e. `gen_task.gen_yaml` instead of `gen_yaml`)
" TODO: when the module path contains mulitple levels(e.g. qlib.utils.data), this will not work.
nnoremap <leader>pdb :SlimeSend0 "b ".expand("%:p").":".line(".")."\n"<CR>
nnoremap <leader>pde :SlimeSend1 from IPython import embed; embed()<CR>

" TODO: Combine the ipython cel and jupyter-vim
" - https://vi.stackexchange.com/a/18946

"

" BEGIN for vim-indent-guides ----------------------------------------------------------
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
let g:indent_guides_exclude_filetypes = ['help', 'nerdtree', 'toggleterm', 'NvimTree']
" END   for vim-indent-guides ----------------------------------------------------------




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





" BEGIN 'jupyter-vim' ----------------------------------------------------------
"
" let g:jupyter_mapkeys=0
" nmap <leader>jc  :<C-u>JupyterSendCount<CR>
" vmap <leader>jc  :<C-u>'<,'>JupyterSendRange<CR>
" " 注意只有disconnect之后才能再次connect
" nmap <leader>js  :<C-u>JupyterConnect 
" nmap <leader>jr  :<C-u>JupyterSendCode 
" nmap <leader>jn  <esc>}o<CR># %%<esc>o
" nmap <leader>jw  :<C-u>JupyterSendCode expand("<cword>")<CR>
" nmap <leader>jl  :<C-u>JupyterSendCode "clear"<CR>
" nmap <leader>jp  :<C-u>JupyterSendCode @"<CR>
"
" nmap <Plug>RunCellAndJump <leader>je/# %%<CR>:noh<CR>
" \:silent! call repeat#set("\<Plug>RunCellAndJump", v:count)<CR>
" nmap <leader>jE <Plug>RunCellAndJump
"
" 依赖vim-repeat 才能
" config come from http://vimcasts.org/episodes/creating-repeatable-mappings-with-repeat-vim/

" END   'jupyter-vim' ----------------------------------------------------------




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


" # 其他有用的
" ## 我还没搞明白它的两种运行机制
" 一种出现quickfix  (Glog)
" ## 在navigate mode下面[疑似]
" 我感觉 navigate 逻辑是这么走的： 从 commit trace -> commmit内容 -> 这个commit内部的文件原文
" - 这些东西都可以在文件中直接打开
"   - tree: commit
"   - +++/--- 文件名
"   - 等等...
" - 下面的命令都可以在这个文件中看到
" p : preview 看看里面是个啥;
" dp: 根据当前光标看看 diff 啥的(到底改了哪里), 可以直接看文件的， 也可以直接看stage的
" = : 在当前 toggle diff;  可以快速地浏览很多文件， 非常好用！！！！
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
nnoremap <F6> :call vimspector#StepOver()<cr>
nnoremap <F7> :call vimspector#StepInto()<cr>
nnoremap <F17> :call vimspector#StepOut()<cr>
" shift + <F7>

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

" `g` and `f` should not be included becausa  we want to able to goto file in a new
" for key in ['a','b','c','d','e', 'h','i','j','k','l','m',
" \           'n','o','p','q','r','s','t','u','v','w','x','y','z']
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
" - <C-up>  <C-down> 之类的功能也能达到类似的效果，目前和和kitty的transparency的功能冲突了
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

nnoremap <silent> <C-P>  :<C-u>Files<CR>

" not include the name of the file  ( `c`  is short for only content)
" https://github.com/junegunn/fzf.vim/issues/346
" command! -bang -nargs=* Agc call fzf#vim#ag(<q-args>, {'options': '--delimiter : --nth 4..'}, <bang>0)
" 其实这里也说了preview怎么一起用

" 上面的命令发现preview 没用后， 在这里找到了能用的句子:   https://github.com/junegunn/fzf.vim/issues/362
command! -bang -nargs=* Agc call fzf#vim#ag(<q-args>, fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}), <bang>0)
command! -bang -nargs=* Rgc
  \ call fzf#vim#grep('rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1, fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right', 'ctrl-/'), <bang>0)

" [solution for long lines](https://github.com/junegunn/fzf.vim/issues/1051)
command! -bang -nargs=* Rg
  \ call fzf#vim#grep('rg --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>), 1, fzf#vim#with_preview('right', 'ctrl-/'), <bang>0)

command! -bang -nargs=* RgPlug
  \ call fzf#vim#grep('rg --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>), 1, fzf#vim#with_preview({'dir': '~/.vim/plugged/'}), <bang>0)
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

" BEGIN 'szw/vim-maximizer' -----------------------------------------
" let g:maximizer_default_mapping_key = '<F5>'
" tnoremap <silent><F5> <c-\><c-n>:MaximizerToggle<CR>
" END   'szw/vim-maximizer' -----------------------------------------



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
