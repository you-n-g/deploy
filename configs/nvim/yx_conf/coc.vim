
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
" nmap <silent> <TAB> <Plug>(coc-range-select)
" xmap <silent> <TAB> <Plug>(coc-range-select)
" xmap <silent> <S-TAB> <Plug>(coc-range-select-backword)
" These features are replaced by tree sitter

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



" scroll the popup
" 一开始是用了这个
" comes from https://github.com/neoclide/coc.nvim/issues/1405
" I think this is still experimental
" 后面我感觉他API改动了，这边就跑不通了
"
" 后来发现其实直接用这个就挺好: https://github.com/neoclide/coc.nvim/issues/1405#issuecomment-674587738
" ctrl+w, w : 进float window
" ctrl+w, q : 出flaot window
" 这个的缺点是不能在 normal mode下操作

" 再后来通过enable tmux和vim的 mouse实现了鼠标翻页

" 再后来终于找到正确解法了： https://github.com/neoclide/coc.nvim/issues/2902
if has('nvim-0.4.0') || has('patch-8.2.0750')
  nnoremap <silent><nowait><expr> <down> coc#float#has_scroll() ? coc#float#scroll(1) : "\<down>"
  nnoremap <silent><nowait><expr> <up> coc#float#has_scroll() ? coc#float#scroll(0) : "\<up>"
  inoremap <silent><nowait><expr> <down> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<down>"
  inoremap <silent><nowait><expr> <up> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<up>"
  vnoremap <silent><nowait><expr> <down> coc#float#has_scroll() ? coc#float#scroll(1) : "\<down>"
  vnoremap <silent><nowait><expr> <up> coc#float#has_scroll() ? coc#float#scroll(0) : "\<up>"
endif


let g:coc_global_extensions = [
 \ "coc-pyright",
 \ "coc-highlight",
 \ "coc-lists",
 \ "coc-json",
 \ "coc-explorer",
 \ "coc-snippets",
 \ "coc-marketplace",
 \ "coc-sh",
 \ "coc-java",
 \ "coc-java-debug",
 \ "coc-marketplace",
 \ "coc-spell-checker",
 \ "coc-sumneko-lua"
 \ ]
"  \ "coc-zi"
" 个人经验 <space>c  setLinter ，把pylama 设置成错误提示的工具方便


" coc-python -------------------
" 如果想用black，那么可以尝试 CocLocalConfig中加入这个
" "python.formatting.provider": "black"
" python.execInTerminal 还是比较好用的
"
" FIXME use coc-pyright: https://github.com/fannheyward/coc-pyright
" coc-pyright ------------------
" 优点
" - 感觉代码补全(带自动import) 更方便了(虽然还不是很确定这是它带来的)
"
" TODO:
" - 我怀疑它还不能自动安装缺失的包 (比如pylint在有的环境中不起作用)
" - self变成 不提示的: https://github.com/fannheyward/coc-pyright/issues/271
"   - 这边有一个思路可以 通过改  pyrightconfig.json 来实现 reportSelfClsParameterName
"     https://github.com/fannheyward/coc-pyright/issues/381#issuecomment-814027504
"     但是我改了没有用
"   - 后面据说在这里改好了: https://github.com/fannheyward/coc-pyright/pull/428


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

function! s:explorer_cur_dir()
  let node_info = CocAction('runCommand', 'explorer.getNodeInfo', 0)
  return fnamemodify(node_info['fullpath'], ':h')
endfunction

function! s:exec_cur_dir()
  let dir = s:explorer_cur_dir()
  " close coc-explorer
  execute 'CocCommand explorer --sources=buffer+,file+ --preset floating'
  " call telescope
  execute 'lua require("telescope.builtin").live_grep({search_dirs={"'.l:dir.'"}})'
endfunction

function! s:init_explorer()
  " set winblend=10
  nnoremap <buffer> <Leader>ff :call <SID>exec_cur_dir()<CR>
endfunction

augroup CocExplorerCustom
  autocmd!
  autocmd FileType coc-explorer call <SID>init_explorer()
augroup END

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
" - NOTE: rg的默认会读入.gitignore (前提是这是个git仓库)
" - 对于floating window的看法: https://github.com/neoclide/coc-lists/issues/61
" 未来有可能的代替品
" - https://github.com/liuchengxu/vim-clap


" coc java 相关 ------------------------
"
" coc-java 一直启动失败(https://github.com/neoclide/coc-java/issues/20)
" - <space>lc workspace.showOutput  java 来看详细信息
" - 表现为:
"   - [java exited with code: 13] 这是用了 troubleshooting 后才能看到的东西
"   -  "⠹ jdt starting" ???
" - 可能的原因
"   - 没有指定11版本以上的jdk
"     - 解决方法: 设置 "java.home":
"   - 未知:
"       - 解决方法: 强行删除文件&重装 https://github.com/neoclide/coc-java/issues/133
"   - gradle有自己的版本要求:
"       - 设置正确的 "java.import.gradle.java.home"
"
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
" - 后来发现 `.vimspector.json` 没有用(参考自coc-java-debug主页)， 得设置 `.gadgets.json` https://github.com/dansomething/coc-java-debug/issues/11#issuecomment-725497630
"       - 再后面发现光有 '.gadgets.json' 也没有用，还是得依赖 '.vimspector.json'
"
" FAQ
" - 如果想要在uncaught exception处设置断点，那么将config的  "breakpoints.exception" 配置改成下面就行
" -  "uncaught": "Y"
"
" 坑
" - 如果启动时忘了从 java.debug.vimspector.start 启动而是从 continue 启动，可能会触发bug导致无法继续连上debugger
"
" 未解决的问题
" - 如何同时import 多个项目，比如 jpf-core 和 jpf-ranger
"  
" Ref:
" - 全面的debug思路: https://github.com/neoclide/coc-java/#troubleshooting




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
" pip install -U jedi 一般可以解决问题；  后来有一次版本更新到太高(0.18.0)也没用，更新到 `pip install "jedi==0.17.2"`
" 才解决问题
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

