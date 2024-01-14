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
  {
    "lervag/vimtex",
    config = function ()
      -- vim.g.vimtex_compiler_method = "tectonic"
      -- tectonic does not support continuous compilation

      local function get_onedrive_path()
        local handle = io.popen([[cmd.exe /c echo %onedriveconsumer% 2> /dev/null | sed -e 's/C:/\\mnt\\c/g' | sed -e 's/\\/\//g' | tr -d '\r' | tr -d '\n']])
        if handle == nil then
          print("Error: result is nil")
        else
          local result = handle:read("*a")
          handle:close()
          return result
        end
      end

      -- It will only works on windows disk
      -- NOTE: this will result in a wrong Path
      vim.g.vimtex_view_general_viewer =  get_onedrive_path() .. '/APP/SumatraPDF/SumatraPDF-3.5.2-64.exe'
      -- vim.g.vimtex_view_general_options = '-reuse-instance @pdf'
      -- vim.g.vimtex_view_general_options = '-reuse-instance /Users/xiaoyang/OneDrive/repos/colm24/main.pdf'
      -- vim.g.vimtex_view_general_options = '-reuse-instance /mnt/c/Users/xiaoyang/OneDrive/repos/colm24/main.pdf'
      -- vim.g.vimtex_view_general_options = '/mnt/c/Users/xiaoyang/OneDrive/repos/colm24/main.pdf'
      -- So Please manually open the PDF.

      -- vim.g.vimtex_view_general_options = vim.fn.getcwd() .. "/main.pdf"
      -- -- strip the left "/mnt/c/" part in vim.g.vimtex_view_general_options if exists
      -- vim.g.vimtex_view_general_options = vim.g.vimtex_view_general_options:gsub("^/mnt/c", "")  -- the prefix / must be kept.
      vim.g.vimtex_view_general_options = "-reuse-instance main.pdf"

      -- NOTE: set default to 100%
      vim.cmd([[
  augroup VimTeX
    autocmd!
    autocmd BufReadPre *.tex let b:vimtex_main = 'main.tex'
  augroup END
]])
    end,
  },
}
