return {
  -- { "folke/persistence.nvim", enabled = false },
  {
    "olimorris/persisted.nvim",
    -- event = "BufReadPre",
    config = function()
      require("persisted").setup()
      require("telescope").load_extension("persisted")
    end,
  },
  -- NOTE: dashboard.nvim is now the default LazyVim starter plugin.
  -- {
  --   "goolord/alpha-nvim",
  --   opts = function(_, opts)
  --     -- local dashboard = opts
  --     local dashboard = require("alpha.themes.dashboard")
  --     -- dashboard.section.buttons.val = {
  --     opts.section.buttons.val = {
  --       dashboard.button("f", " " .. " Find file", ":Telescope find_files <CR>"),
  --       dashboard.button("n", " " .. " New file", ":ene <BAR> startinsert <CR>"),
  --       dashboard.button("r", " " .. " Recent files", ":Telescope oldfiles <CR>"),
  --       dashboard.button("g", " " .. " Find text", ":Telescope live_grep <CR>"),
  --       dashboard.button("c", " " .. " Config", ":e $MYVIMRC <CR>"),
  --       dashboard.button("s", " " .. " Restore Session", [[:lua require("persisted").load() <cr>]]),
  --       dashboard.button("S", "T " .. " Restore Session(T)", [[:Telescope persisted<cr>]]),
  --       dashboard.button("l", "󰒲 " .. " Lazy", ":Lazy<CR>"),
  --       dashboard.button("q", " " .. " Quit", ":qa<CR>"),
  --     }
  --     for _, button in ipairs(dashboard.section.buttons.val) do
  --       button.opts.hl = "AlphaButtons"
  --       button.opts.hl_shortcut = "AlphaShortcut"
  --     end
  --   end
  -- },
}
