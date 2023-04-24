return {
  {
    "L3MON4D3/LuaSnip",
    -- TODO: add as
    config = function(_, opts)
      require("luasnip").setup(opts) -- default behaviour: https://github.com/folke/lazy.nvim#-plugin-spec
      require("luasnip.loaders.from_vscode").lazy_load({ paths = { "./luasnip_snippets" } })
      require("luasnip.loaders.from_lua").load({ paths = "./luasnip_snippets" })
      require("luasnip.loaders.from_snipmate").load({ paths = "./luasnip_snippets" })
    end,
  },
}
