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
      fast_wrap = {
        pattern = [=[[%'%"%>%]%)%}%,%.%:%=]]=],
        use_virt_lines = false,  -- The vertual line will overlap with the code auto completion.
      },
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
    -- NOTE: cheatsheets
    -- Prequisites(to be automated):
    -- - You should create a main.tex file. I often use softlink
    -- - Using `bibtex main` to compile `main.bib` to support more
    -- Frequently used commands:
    -- - <localleader>ll: to start (continuous) compiling.
    -- - <localleader>lv: to view the compiled document.
    --
    config = function ()
      -- vim.g.vimtex_compiler_method = "tectonic"
      -- tectonic does not support continuous compilation; So we use the preferred compiler backend(latexmk).

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

      -- vim.g.vimtex_view_general_options = vim.fn.getcwd() .. "/main.pdf"
      -- -- strip the left "/mnt/c/" part in vim.g.vimtex_view_general_options if exists
      -- vim.g.vimtex_view_general_options = vim.g.vimtex_view_general_options:gsub("^/mnt/c", "")  -- the prefix / must be kept.
      -- NOTE: it will not work when pwd does not match with the location of @tex.  It will concat the relative path with the @tex location.
      -- vim.g.vimtex_view_general_options = "-reuse-instance -forward-search @tex @line @pdf"  -- this will be much simpler than above methods
      -- NOTE: the path does not work. It only works after adding deploy/helper_scripts/bin/cygpath into the bin search path
      vim.g.vimtex_view_general_options = "-reuse-instance @pdf"  --It seems the path to @tex can't be rightly handled. So we skip them

      -- NOTE: set default to main.tex (We don't need this now)
      -- It seems that the vimtex will prompt you to make the choice. But it may affect `simplegpt.nvim` everytime when you create a buffer with specific type.
--       vim.cmd([[
--   augroup VimTeX
--     autocmd!
--     autocmd Filetype tex echo expand("%")
--     autocmd Filetype tex let b:vimtex_main = 'main.tex'
--   augroup END
-- ]])
      -- vim.g.vimtex_parser_bib_backend = "bibtex"  -- default value is `lua`, All of them do not work for me.
    end,
  },
}
