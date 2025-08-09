-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt
opt.wrap = true -- enable line wrap
opt.fencs = "ucs-bom,utf-8,euc-cn,cp936,gb18030,latin1" -- to support gbk chinese

-- TODO: All these does not work. I think it is related to both Mobaxterm & neovim
-- opt.gcr = "a:NoiceHiddenCursor,"
-- opt.gcr = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"
-- opt.gcr = "n-v-c-sm:block,ci-ve:ver25,r-cr-o:hor20,i:block-blinkwait700-blinkoff400-blinkon250-Cursor/lCursor"


-- change the default shell to powershell if windows
if vim.fn.has("win32") == 1 then
   -- https://www.reddit.com/r/neovim/comments/vpnhrl/how_do_i_make_neovim_use_powershell_for_external/
   opt.shell = "powershell"
   opt.shellcmdflag="-command"
   opt.shellquote='"'
   opt.shellxquote=''
end

vim.g.autoformat = false

-- set conceallevel=0 when in tex file
vim.cmd [[ autocmd FileType tex setlocal conceallevel=0 ]]

-- vim.opt.expandtab = true

-- disable relative line number by default
opt.relativenumber = false

-- Set swap file directory to be near the original file location
-- It will be easier to clean swap file; However, it may cause problem when you are using gitdiffview, and result in "fail to create diff buffer"
-- opt.directory = '.'

-- TODO: create a command to clean the swap file below
-- ls ~/.local/state/nvim/swap/

-- Filetypes
vim.filetype.add {
    pattern = {
        -- ssh config
        ['.*%/.*%.?ssh%.config']         = 'sshconfig',
        ['.*%/.*%.?ssh%/config']         = 'sshconfig',
        ['.*%/.*%.?ssh%/.*%.config']     = 'sshconfig',
        ['.*%/.*%.?ssh%/.*%/config']     = 'sshconfig',
        ['.*%/.*%.?ssh%/.*%/.*%.config'] = 'sshconfig',
    },
}
