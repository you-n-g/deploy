return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        -- ["<leader>L"] = { name = "+LuaJit" },
        -- ["<leader>r"] = { name = "+REPL" },
        -- ["<leader>re"] = { name = "+REPL(edit)" },
        -- ["<leader>rc"] = { name = "+REPL(config)" },
        -- ["<leader>rd"] = { name = "+REPL(?db)" },
        -- -- ["<leader>rL"] = { name = "+REPL(launch)" },
        -- ["<leader><tab>"] = { name = "+tabs & windows" },
        -- ["<leader>]"] = { name ="+Copilot" },

        { "<leader><tab>", group = "tabs & windows" },
        { "<leader>L", group = "LuaJit" },
        { "<leader>]", group = "Copilot" },
        { "<leader>r", group = "REPL" },
        { "<leader>rc", group = "REPL(config)" },
        { "<leader>rd", group = "REPL(?db)" },
        { "<leader>re", group = "REPL(edit)" },
        -- {"<leader>rL", group = "REPL(launch)" },
      },
    },
  },
}
