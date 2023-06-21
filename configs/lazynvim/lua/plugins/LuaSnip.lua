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
  },
}
