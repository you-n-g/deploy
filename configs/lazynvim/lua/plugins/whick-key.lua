return {
  {
    "folke/which-key.nvim",
    opts = {
      defaults = {
        ["<leader>L"] = { name = "+LuaJit" },
        ["<leader>r"] = { name = "+REPL" },
        ["<leader>re"] = { name = "+REPL(edit)" },
        -- ["<leader>rL"] = { name = "+REPL(launch)" },
        ["<leader><tab>"] = { name = "+tabs & windows" },
      },
    },
  },
}
