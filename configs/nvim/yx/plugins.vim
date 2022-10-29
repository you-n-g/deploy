call plug#begin('~/.vim/plugged')
" cspell:disable
Plug 'tomtom/tcomment_vim'

Plug 'dhruvasagar/vim-table-mode'
Plug 'nathanaelkane/vim-indent-guides'

" 这里需要依赖 https://github.com/ryanoasis/nerd-fonts, 需要在本地安装字体, DejaVu(favorite)
Plug 'ryanoasis/vim-devicons'
Plug 'mhinz/vim-startify'
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

Plug 'machakann/vim-sandwich'

Plug 'ludovicchabant/vim-gutentags'  " 自动生成更新ctags
" tags围绕tag stack进行,  ctrl+t pop操作， ctrl+] push操作(如果找得到顺便jump一下)

Plug 'puremourning/vimspector'
Plug 'kana/vim-submode'

" NOTE: 还没看具体教程
Plug 'mg979/vim-visual-multi'

Plug 'kkoomen/vim-doge', { 'do': { -> doge#install() } }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'APZelos/blamer.nvim'
" https://github.com/phaazon/hop.nvim 是不是可以替代 easymotion
Plug 'easymotion/vim-easymotion'

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

Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'


Plug 'voldikss/vim-translator'

Plug 'akinsho/toggleterm.nvim'
" - 试用的困难请在 yx 中查找


" Plug 'untitled-ai/jupyter_ascending.vim'
" 这种模式我非常喜欢，但是现在还有不足的地方
" - 它运行cell的时候感觉位置不对, 等待这个错误的解决
"   https://github.com/untitled-ai/jupyter_ascending.vim/issues/8

" This Plugin only controls the starting and ending of the container. It does
" not embed neovim into the container...
" Plug 'jamestthompson3/nvim-remote-containers'


Plug 'moll/vim-bbye'

" just for help tags
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

Plug 'neovim/nvim-lspconfig'
Plug 'nvim-treesitter/playground' " treesitter dependent

" lsp auto completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'L3MON4D3/LuaSnip'
" Plug 'quangnguyen30192/cmp-nvim-ultisnips'

" Dev lua
" Plug 'tjdevries/nlua.nvim'  "  this seems  require builtin lsp
Plug 'bfredl/nvim-luadev'
call plug#end()

" cspell:enable




" There are some issues.  It will not retain the last cursor position if it is
" enabled
" runtime yx/plug/stop_open.vim
