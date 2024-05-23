return {
  {
    "L3MON4D3/LuaSnip",
    -- TODO: add as
    config = function(_, opts)
      opts["enable_autosnippets"] = true
      -- This is necessary. Otherwise snippets like pypdb with  `"autotrigger": true` will not work
      require("luasnip").setup(opts) -- default behaviour: https://github.com/folke/lazy.nvim#-plugin-spec
      require("luasnip.loaders.from_vscode").lazy_load({ paths = { "./luasnip_snippets" } })
      require("luasnip.loaders.from_lua").load({ paths = "./luasnip_snippets" })
      require("luasnip.loaders.from_snipmate").load({ paths = "./luasnip_snippets" })
    end,
    -- NOTE: cheatsheets
    -- - Config documents: https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
    keys = {
      {
        "<leader>sN",
        -- `only_sort_text=true` will only search text without filename
        -- https://github.com/nvim-telescope/telescope.nvim/issues/564
        -- [[:Telescope grep_string only_sort_text=true<cr>]],
        function()
          local search_path = vim.fn.expand("~/.config/nvim/luasnip_snippets")  -- TODO: get the absolute path of the path.
          require'telescope.builtin'.live_grep{ cwd = search_path, search = '' }
          -- The file name are very clear to user. So we don't include it in the search.
          -- require'telescope.builtin'.grep_string{cwd=search_path, shorten_path = true, word_match = "-w", only_sort_text = false, search = '' }
        end,
        mode = "n",
        desc = "Search by snippets content",
      },
      -- sNf to use telescope to select the right snippet file
      {
        "<leader>fN",
        function()
          local search_path = vim.fn.expand("~/.config/nvim/luasnip_snippets")
          require'telescope.builtin'.find_files{ cwd = search_path }
        end,
        mode = "n",
        desc = "Select snippet file",
      },
    },
  },
}
