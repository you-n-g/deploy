" Principles of neovim configs
" init.nvim: 入口文件;   然后内容按  plugin & conf 分成了两类
" - yx/plugins.vim : 汇总各种 plugin 的安装 & 开关
" - yx/conf.vim : 汇总和插件无关的配置信息;  Conf里面可以放一些通用的 cheatsheet
" - yx/plugins_conf.vim :  plugin conf的开关 &  不想分出去的conf信息
" - yx/plugs/XXXX[_conf].vim : 太大的拆分出去的 plugins 或者conf
"
"   能支持其完整功能的叫feature/plugin， 只是对齐功能做配置的叫config
"
" - lua/yx/ 下面也有一套完全一样的内容
"

runtime yx/plugins.vim
runtime yx/conf.vim
runtime yx/plugins_conf.vim

lua << EOF
require("yx/plugins")
require("yx/conf")
require("yx/plugins_conf")
EOF


" TODO:
" code formatting不太好用
" [X] autopep8 这个老插件可能能解决这个问题;  最后用 black-macchiato 解决的
" snippet 相关
" [ ] convert to snippet 不够方便
" [X] pypdb 不管用了
" 在terminal 里面 gf， 把它打开到 最大的那个 windows中



" Neovim有的缺陷:



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
" - 按键不一定会按你想的那样； 比如 <C-1> 不会映射到特定的按钮
"   - 参见 https://vi.stackexchange.com/a/19359

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
