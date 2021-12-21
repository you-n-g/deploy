-- https://github.com/nanotee/nvim-lua-guide

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
  }
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


require("nvim-treesitter.configs").setup {
  highlight = {
      -- ...
  },
  -- ...
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
