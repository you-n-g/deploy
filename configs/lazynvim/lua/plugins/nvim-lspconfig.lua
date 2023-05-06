return {
  {"neovim/nvim-lspconfig",
    opts={autoformat = false,},

    keys = {
      -- The default config only cover <c-f> & <c-b>; <c-b> conflicts with tmux
      { "<c-d>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward", mode = {"i", "n", "s"} },
      { "<c-u>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward", mode = {"i", "n", "s"}},
    },
  }
  -- I don't like the autoformat feature of nvim-lspconfig. It will change the code and produce unexpected git commits.
}
