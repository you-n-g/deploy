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
      fast_wrap = {},
    },
  },
  {
    "kkoomen/vim-doge",
    build = ":call doge#install()", -- <cr> is not required
    init = function()
      -- This configuration only works if set before startup, rather than after loading plugins.
      vim.g.doge_doc_standard_python = "numpy"
      vim.g.doge_mapping = "<leader>cD"
    end,
  },
}
