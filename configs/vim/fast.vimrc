" The editor Claude Code / Codex open on Ctrl+G (vim-fast): a prompt or a reply
" to edit, so it must come up at once. No plugins, no swap file, no viminfo;
" only what makes writing prose comfortable. fast-sentences.vim adds the
" 0-9 saved sentences below the draft.
set nocompatible
set encoding=utf-8 fileencoding=utf-8
set backspace=indent,eol,start
set wrap linebreak breakindent
set ruler showcmd laststatus=1
set incsearch hlsearch ignorecase smartcase
set noswapfile nobackup nowritebackup
set mouse=a
syntax on
" q in normal mode: save (only if changed) and quit, handing the text back.
" BufWriteCmd keeps the sentence list out of that file.
nnoremap q :x<CR>
execute 'source' fnameescape(fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/fast-sentences.vim')
