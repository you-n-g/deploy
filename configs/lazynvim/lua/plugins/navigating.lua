return {

  {
    "nvim-telescope/telescope.nvim",
    -- change some options
    opts = {
      defaults = {
        -- TODO: make it larger for content preview, less for file list
        layout_strategy = "vertical",
        layout_config = {
          -- prompt_position = "top",
          -- width = 0.95,
          -- height = 0.95,
          width = 0.99,
          height = 0.99,
        },
        -- sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    opts = {
      -- "default-title",
      winopts = {
        width = 0.99,
        height = 0.99,
        preview = {
          vertical = "up:45%",
          layout = "vertical",
        },
      },
    },
    -- shortcuts:
    -- - shift + <up/down> to scroll up/down in the content preview.
  },
  -- {
  --     "otavioschwanck/arrow.nvim",
  --     opts = {
  --         show_icons = true,
  --         -- leader_key = ';', -- Recommended to be a single key
  --         leader_key = '<m-h>', -- Recommended to be a single key
  --         buffer_leader_key = '<m-m>', -- Per Buffer Mappings
  --     }
  -- },

  -- {
  --   -- NOTE:
  --   -- I need more;
  --   -- - Line number
  --   --    We may find alternatives here https://github.com/you-n-g/awesome-neovim?tab=readme-ov-file#marks
  --   -- - Support ident for tracing
  --   -- - Support note taking
  --   -- A lot of people think it is not useful
  --   -- - BufferLineTogglePin can create fix buffer: https://www.reddit.com/r/neovim/comments/1bh3npw/comment/kvdz1rr/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
  --   -- NOTE: How I use it.
  --   -- Orgnized it in the calling level.
  --   "ThePrimeagen/harpoon",
  --   branch = "harpoon2",
  --   -- config = true,
  --   -- config = { settings = { save_on_toggle = true } },
  --   config=function ()
  --     require("harpoon"):setup({settings = {save_on_toggle = true}})
  --   end,
  --   keys = {
  --     {
  --       "<leader>ha",
  --       function()
  --         require("harpoon"):list():add()
  --       end,
  --       mode = "n",
  --       desc = "Add to Harpoon list",
  --     },
  --     {
  --       -- "<leader>he",
  --       "<m-h>",  -- <esc>h will also trigger this
  --       function()
  --         require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
  --       end,
  --       mode = "n",
  --       desc = "Toggle Harpoon quick menu",
  --     },
  --     {
  --       "<leader>h1",
  --       function()
  --         require("harpoon"):list():select(1)
  --       end,
  --       mode = "n",
  --       desc = "Select first item in Harpoon list",
  --     },
  --     {
  --       "<leader>h2",
  --       function()
  --         require("harpoon"):list():select(2)
  --       end,
  --       mode = "n",
  --       desc = "Select second item in Harpoon list",
  --     },
  --     {
  --       "<leader>h3",
  --       function()
  --         require("harpoon"):list():select(3)
  --       end,
  --       mode = "n",
  --       desc = "Select third item in Harpoon list",
  --     },
  --     {
  --       "<leader>h4",
  --       function()
  --         require("harpoon"):list():select(4)
  --       end,
  --       mode = "n",
  --       desc = "Select fourth item in Harpoon list",
  --     },
  --     -- Toggle previous & next buffers stored within Harpoon list
  --     {
  --       "<leader>hh",
  --       function()
  --         require("harpoon"):list():prev()
  --       end,
  --       mode = "n",
  --       desc = "Select previous buffer in Harpoon list",
  --     },
  --     {
  --       "<leader>hl",
  --       function()
  --         require("harpoon"):list():next()
  --       end,
  --       mode = "n",
  --       desc = "Select next buffer in Harpoon list",
  --     },
  --   },
  --   dependencies = { "nvim-lua/plenary.nvim" },
  -- },

  -- 有一种脱了裤子放屁的感觉...
  -- {
  --   "RutaTang/quicknote.nvim",
  --   config=function()
  --     -- you must call setup to let quicknote.nvim works correctly
  --     require("quicknote").setup({})
  --   end,
  --   dependencies = { "nvim-lua/plenary.nvim"}
  -- },
  {
    url = "git@github.com:you-n-g/navigate-note.nvim",
    config = true,
    event = "VeryLazy", -- greatly boost the initial of neovim
    opts = {
      context_line_count = { -- it would be total `2 * context_line_count - 1` lines
        -- tab = 5,
        -- vline = 2,
      },
      -- link_surround = {
      --   left = "{{",
      --   right = "}}"
      -- },
      enable_block = true,
      default_tmux_target = "T:{current}.gemini",
    },
  },
  -- It conflicts with https://github.com/jbyuki/one-small-step-for-vimkind?tab=readme-ov-file#flattennvim
  -- FIXME: nest_if_no_args = true, don't solve this issue
  -- {
  --   "willothy/flatten.nvim",
  --   -- config = true,
  --   -- or pass configuration with
  --   -- opts = { window = { open = "alternate" } },
  --   opts = {
  --     window = { open = "smart" },
  --     nest_if_no_args = true,
  --   },
  --   -- Ensure that it runs first to minimize delay when opening file from terminal
  --   lazy = false,
  --   priority = 1001,
  -- },
}
