return {
  -- NOTE: we disable it due to lacking of following features.
  -- 1. Multiple quote pairing is not supported in the future (https://github.com/echasnovski/mini.nvim/discussions/255)
  -- 2. fast wrap is not supported
  { "echasnovski/mini.pairs", enabled = false },
  -- instead an alternative is used
  -- - https://github.com/jiangmiao/auto-pairs may be another alternative
  -- { "windwp/nvim-autopairs", event = "VeryLazy", config = true },
  {
    "windwp/nvim-autopairs",
    -- config = true  -- if opts is missing, we have to use config = true to enable `setup`. otherwise, it is not needed
    opts = {
      fast_wrap = { pattern = [=[[%'%"%>%]%)%}%,%:]]=],},
    },
  },
  -- {
  --   "kkoomen/vim-doge",
  --   build = ":call doge#install()", -- <cr> is not required
  --   init = function()
  --     -- This configuration only works if set before startup, rather than after loading plugins.
  --     vim.g.doge_doc_standard_python = "numpy"
  --     vim.g.doge_mapping = "<leader>cD"
  --   end,
  -- },
  {
    -- NOTE: the support of <tab> is included in the setting of "hrsh7th/nvim-cmp"
    "danymat/neogen",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        {
          "hrsh7th/nvim-cmp",
          opts = function(_, opts)
            -- enhance the <tab> for neogen
            local cmp = require("cmp")
            local mapping = {
              ["<tab>"] = cmp.mapping(function(fallback)
                local neogen = require("neogen")
                if neogen.jumpable() then
                  neogen.jump_next()
                else
                  fallback()
                end
              end, {
                "i",
                "s",
              }),
              ["<S-tab>"] = cmp.mapping(function(fallback)
                local neogen = require("neogen")
                if neogen.jumpable(true) then
                  neogen.jump_prev()
                else
                  fallback()
                end
              end, {
                "i",
                "s",
              }),
            }
            opts.mapping = vim.tbl_extend("error", opts.mapping, mapping)
          end,
        },
    },
    config = true,
    -- Uncomment next line if you want to follow only stable versions
    -- version = "*"
    keys = {
      { "<leader>cD", [[<cmd>lua require('neogen').generate({ annotation_convention = { python = 'numpydoc' } })<cr>]], desc = "Generating Docs" },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    keys = {
      { "<c-]>", [[<cmd>lua require("copilot.panel").open()<cr>]], mode = { "n", "i" }, desc = "Open Copilot Penel" },
      { "<leader>]]", [[<cmd>lua require("copilot.panel").jump_next()<cr>]], mode = { "n" }, desc = "Next Suggestion" },
      { "<leader>][", [[<cmd>lua require("copilot.panel").jump_prev()<cr>]], mode = { "n" }, desc = "Prev Suggestion" },
      { "<leader>]<cr>", [[<cmd>lua require("copilot.panel").accept()<cr>]], mode = { "n" }, desc = "Accept Suggestion" },
    },
  },
}
