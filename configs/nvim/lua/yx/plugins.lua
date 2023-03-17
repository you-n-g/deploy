-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
-- vim.cmd [[packadd packer.nvim]]

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])


-- NOTE:  the repository path locates in ~/.local/share/nvim/site/pack/packer/start
local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end

local packer_bootstrap = ensure_packer()

local M = require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    -- My plugins here
    -- use 'foo1/bar1.nvim'
    -- use 'foo2/bar2.nvim'

    use 'simrat39/symbols-outline.nvim'
    -- FIXME: waiting for the fix of the bug https://github.com/simrat39/symbols-outline.nvim/issues/176
    -- use {
    --     "rbjorklin/symbols-outline.nvim",
    --     branch = "fix-outline-detection"
    -- }

    use {
        'nvim-tree/nvim-tree.lua',
        requires = {
            'nvim-tree/nvim-web-devicons', -- optional, for file icons
        },
        tag = 'nightly' -- optional, updated every week. (see issue #1193)
    }

    -- Only for converting snippets
    -- use {
    --   "smjonas/snippet-converter.nvim",
    --   -- SnippetConverter uses semantic versioning. Example: use version = "1.*" to avoid breaking changes on version 1.
    --   -- Uncomment the next line to follow stable releases only.
    --   -- tag = "*",
    --   config = function()
    --     local template = {
    --       -- name = "t1", (optionally give your template a name to refer to it in the `ConvertSnippets` command)
    --       sources = {
    --         ultisnips = {
    --           -- Add snippets from (plugin) folders or individual files on your runtimepath...
    --           vim.fn.stdpath("config") .. "/snips",
    --         },
    --       },
    --       output = {
    --         -- Specify the output formats and paths
    --         vscode_luasnip = {
    --           vim.fn.stdpath("config") .. "/luasnip_snippets",
    --         },
    --       },
    --     }
    --
    --     require("snippet_converter").setup {
    --       templates = { template },
    --       -- To change the default settings (see configuration section in the documentation)
    --       -- settings = {},
    --     }
    --   end
    -- }

    -- NOTE: theme related
    use {'akinsho/bufferline.nvim', tag = "v3.*", requires = 'nvim-tree/nvim-web-devicons'}
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'kyazdani42/nvim-web-devicons', opt = true }
    }
    -- use 'Mofiqul/vscode.nvim'
    -- use 'navarasu/onedark.nvim'
    use 'folke/tokyonight.nvim'
    -- use { "ellisonleao/gruvbox.nvim" }
    -- FIXME:  整个scheme看起来灰蒙蒙的，有很多原来能区分的颜色现在也区分不出来（比如亮白色和普通白色）， 这个在terminal里面也存在这个问题
    -- 后来又确认了一下， 之前的color schema也是有这个问题的

    -- use "lukas-reineke/lsp-format.nvim"

    use 'smbl64/vim-black-macchiato'
    -- This may be better for all language
    -- https://github.com/MunifTanjim/prettier.nvim

    use { "beauwilliams/focus.nvim", config = function() require("focus").setup() end }

    -- use('jose-elias-alvarez/null-ls.nvim')
    -- use('MunifTanjim/prettier.nvim')

    -- TODO: The coding workflow can be improved futther with following potential useful plugins
    -- English spelling:
    -- - https://www.reddit.com/r/neovim/comments/w3rgnw/english_grammar_checker_plugin_in_neovim/

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end
end)

--- My plugins; it should appear after installation of basic packages.
require "yx/plugs/run_func"

return M

-- 这里记录一下从 coc.nvim 换成 lsp 遇到的困难
-- - ultisnips 转化成 LuaSnip 非常困难
-- - 学习 lsp 的语法（不像coc会自动安装 language server）
-- - 新换了lua-based color scheme后，原来的一些配的可能会想换一换
-- - [  ] formatting ..... 似乎这个功能没有原来那么好用
-- 改完之后的主要优势
-- - 很多提示好像变得更友好(比如shell)，样式也更好
-- - 一些类似于 rename 的两码补全功能也更好用了
