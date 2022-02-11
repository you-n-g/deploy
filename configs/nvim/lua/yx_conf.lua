-- lua cheatsheets
-- - https://github.com/nanotee/nvim-lua-guide
-- - https://devhints.io/lua
-- APIs (列几个使用频率较高的)
-- - nvim api: help api,  可以通过 vim.api.XXX 调用
-- - vim.fn.XXX 直接调用vimscripts 的functions
-- - vim eval: help eval, 可以通过 vim.fn.XXX 调用
-- - vim.cmd("new") 可以执行一片命令, vim.api.nvim_command() 用于执行一行命令
-- vim.api.nvim_set_keymap('i', '<Tab>', 'v:lua.smart_tab()', {expr = true, noremap = true})

--
-- TODO:
-- 快速切换出buffer: https://codereview.stackexchange.com/questions/268130/get-list-of-buffers-from-current-neovim-instance

-- require'lspconfig'.pyright.setup{}

require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  ignore_install = {  }, -- List of parsers to ignore installing
  highlight = {
    enable = true,              -- false will disable the whole extension
    disable = { },  -- list of language that will be disabled
    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
  indent = {
      enable = true
  },
}


require "nvim-treesitter.configs".setup {
  playground = {
    enable = true,
    disable = {},
    updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
    persist_queries = false, -- Whether the query persists across vim sessions
    keybindings = {
      toggle_query_editor = 'o',
      toggle_hl_groups = 'i',
      toggle_injected_languages = 't',
      toggle_anonymous_nodes = 'a',
      toggle_language_display = 'I',
      focus_language = 'f',
      unfocus_language = 'F',
      update = 'R',
      goto_node = '<cr>',
      show_help = '?',
    },
  }
}
-- inspired by https://vi.stackexchange.com/a/2363
-- for i = 1,2 do
--     vim.api.nvim_command("set <M-"..tostring(i)..">=\\e1")
-- end

for k, mode in pairs({'i','v','n'}) do
    for i = 1,4 do
        -- vim.api.nvim_set_keymap(mode, "<c-"..tostring(i)..">", "<cmd>ToggleTerm "..tostring(i).."<cr>", {expr = true, noremap = true})
        vim.api.nvim_set_keymap(mode, "<F"..tostring(i)..">", "<cmd>ToggleTerm "..tostring(i).."<cr>", {expr = false, noremap = true})
        -- expr = false 非常重要； 不然就会触发 vim mapping 的  <expr> 机制， 导致先用vim命令执行一遍， 再把结果作为map的目标
    end
end



require'nvim-treesitter.configs'.setup {
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<tab><tab>", -- I want <tab>. But it will conflict with vim-visual-multi
                                     -- To be compatible wtih which-key, please use '\t' in triggers_blacklist
                                     -- https://github.com/folke/which-key.nvim/issues/185
      node_incremental = "<tab>",
      -- scope_incremental = "<tab>",  这个会扩展非常多， 感觉不容易用上
      node_decremental = "<s-tab>",
    },
  },
}

require'nvim-treesitter.configs'.setup {
  rainbow = {
    enable = true,
    -- disable = { "jsx", "cpp" }, list of languages you want to disable the plugin for
    extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    max_file_lines = nil, -- Do not enable for files with more than n lines, int
    -- colors = {}, -- table of hex strings
    -- termcolors = {} -- table of colour name strings
  }
}

require("run_func")

require("which_key")



-- 不知道为什么我的telescope 出问题而且无法配置了
-- require('telescope').setup({
--   defaults = {
--     layout_config = {
--       vertical = { width = 0.2 }
--       -- other layout configuration here
--     },
--     -- other defaults configuration here
--   },
--   -- other configuration values here
-- })

require'telescope'.load_extension'my_config'
-- require'telescope'.load_extension'view'  -- 写着着卡住了




-- 用起来还有下面的问题
-- - 如果想快速全屏显示，还有点麻烦
require("toggleterm").setup{
  -- size can be a number or function which is passed the current terminal
  size = function(term)
    if term.direction == "horizontal" then
      return 15
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  open_mapping = [[<c-\><c-\>]],
  -- on_open = fun(t: Terminal), -- function to run when the terminal opens
  hide_numbers = true, -- hide the number column in toggleterm buffers
  shade_filetypes = {},
  shade_terminals = true,
  -- shading_factor = '<number>', -- the degree by which to darken to terminal colour, default: 1 for dark backgrounds, 3 for light
  -- start_in_insert = true,
  start_in_insert = false,
  insert_mappings = true, -- whether or not the open mapping applies in insert mode
  persist_size = true,
  -- direction = 'vertical' | 'horizontal' | 'window' | 'float',
  -- direction = 'float',
  direction = 'horizontal',
  close_on_exit = true, -- close the terminal window when the process exits
  shell = vim.o.shell, -- change the default shell
  -- This field is only relevant if direction is set to 'float'
  float_opts = {
    -- The border key is *almost* the same as 'nvim_open_win'
    -- see :h nvim_open_win for details on borders however
    -- the 'curved' border is a custom border type
    -- not natively supported but implemented in this plugin.
    -- border = 'single' | 'double' | 'shadow' | 'curved' | ... other options supported by win open
    -- width = <value>,
    -- height = <value>,
    -- winblend = 3,
    highlights = {
      border = "Normal",
      background = "Normal",
    }
  }
}


