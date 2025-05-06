-- TODO:
-- - Will the selected message be sent when we start chatting?
-- NOTE:
-- - Minimal shortcuts: https://github.com/jackMort/ChatGPT.nvim#interactive-popup
-- FAQ:
-- - `curl: (3) URL using bad/illegal format or missing URL` -> 密码过期了，gpg -d 去解码。。。

-- get all the content above current cursor
local set_context = function()
  local line = vim.fn.getline(".")
  local content = ""
  for i = 1, vim.fn.line(".") do
    content = content .. vim.fn.getline(i) .. "\n"
  end
  content = content .. line
  -- set content to register "c"
  vim.fn.setreg("c", content)
end

local modules = {
  -- - Perhaps this would be better: https://github.com/Robitx/gp.nvim. It appears simple, yet comprehensive.
  -- - It does not work  well in my terminal finally.
  --  {
  --    	"robitx/gp.nvim",
  --      config = function()
  --        -- require("gp").setup()
  --
  --        -- or setup with your own config (see Install > Configuration in Readme)
  --        local conf = {
  --          	openai_api_key = "<KEY>",
  --            -- api endpoint (you can change this to azure endpoint)
  --            openai_api_endpoint = "https://$URL.openai.azure.com/openai/deployments/{{model}}/chat/completions?api-version=2023-03-15-preview",
  -- -- prefix for all commands
  --            chat_model = { model = "gpt-4-32k"}
  --        }
  --        require("gp").setup(conf)
  --
  --        -- shortcuts might be setup here (see Usage > Shortcuts in Readme)
  --      end,
  --      keys = {
  --        {"<C-g>c", "<cmd>GpChatNew<cr>", mode = {"n", "v"}, desc = "New Chat"},
  --        {"<C-g>t", "<cmd>GpChatToggle<cr>", mode = {"n", "v"}, desc = "Toggle Popup Chat"},
  --        {"<C-g>f", "<cmd>GpChatFinder<cr>", mode = {"n", "v"}, desc = "Chat Finder"},
  --        {"<C-g>r", "<cmd>GpRewrite<cr>", mode = {"n", "v"}, desc = "Inline Rewrite"},
  --        {"<C-g>a", "<cmd>GpAppend<cr>", mode = {"n", "v"}, desc = "Append"},
  --        {"<C-g>b", "<cmd>GpPrepend<cr>", mode = {"n", "v"}, desc = "Prepend"},
  --        {"<C-g>e", "<cmd>GpEnew<cr>", mode = {"n", "v"}, desc = "Enew"},
  --        {"<C-g>p", "<cmd>GpPopup<cr>", mode = {"n", "v"}, desc = "Popup"},
  --        {"<C-g>s", "<cmd>GpStop<cr>", mode = {"n", "v"}, desc = "Stop"},
  --      },
  --  },
  {
    "jackMort/ChatGPT.nvim",
    branch = "main",
    event = "VeryLazy",
    config = function()
      local action_path
      if vim.fn.has("win32") ~= 1 then
        action_path = vim.fn.expand("$HOME") .. "/.config/nvim/lua/plugins/action.json"
      else
        action_path = vim.fn.expand("$LOCALAPPDATA") .. "/nvim/lua/plugins/action.json"
      end
      -- P(action_path)
      local opts = {
        -- set it to shift+enter
        -- table get or set values
        edit_with_instructions = {
          keymaps = {
            use_output_as_input = "<c-a>", -- sw(a)p. <c-i> is expand as tab in my terminal
            -- yank_last = "<c-e>", -- accept , <c-y> is occupied by accept;  this does not work..
            -- accept = "<c-e>", -- this will not make yank_last work in <c-y>
          },
        },
        popup_layout = {
          center = {
            width = "99%",
            height = "99%",
          },
        },
        actions_paths = { action_path },
      }
      if vim.fn.has("win32") ~= 1 then
        local cred = require("extra_fea.utils").get_cred()
        if cred.type == "azure" then
          vim.env.OPENAI_API_TYPE = cred.type
          vim.env.OPENAI_API_BASE = cred.api_base
          vim.env.OPENAI_API_AZURE_ENGINE = cred.model
          vim.env.OPENAI_API_KEY = cred.api_key
          -- vim.env.OPENAI_API_AZURE_ENGINE = "o3-mini" -- cred.model
          -- vim.env.OPENAI_API_AZURE_VERSION = "2024-12-01-preview"
        else
          vim.env.OPENAI_API_KEY = cred.api_key
          vim.env.OPENAI_API_HOST = cred.api_base
        end
        -- require("extra_fea.utils").export_cred_env()
      end
      require("chatgpt").setup(opts)
      -- config whick key with ["<leader><tab>"] = { name = "+tabs & windows" },
      -- require("which-key").register({
      --   ["<leader>"] = {
      --     ["G"] = { name = "ChatGPT" },
      --   },
      -- })
      require("which-key").add({
        { "<leader>G", group = "ChatGPT" },
      })
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "folke/trouble.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      -- it costs money, so G is used..
      { "<leader>Gt", "<cmd>ChatGPT<cr>", mode = { "n", "x" }, desc = "Toggle GPT" },
      { "<leader>Gg", "<cmd>ChatGPTRun grammar_correction<cr>", mode = { "n", "x" }, desc = "Fix Grammar" },
      {
        "<leader>Gc",
        "<cmd>ChatGPTCompleteCode<cr>",
        mode = { "n", "x" },
        desc = "Code Complete",
      },
      { "<leader>Gr", ":ChatGPTRun ", mode = { "n", "x" }, desc = "GPT Run" },
      { "<leader>Ga", "<cmd>ChatGPTActAs<cr>", mode = { "n", "x" }, desc = "GPT Act As" },
      {
        "<leader>Ge",
        "<cmd>ChatGPTEditWithInstructions<cr>",
        mode = { "n", "x" },
        desc = "GPT Instruct Edit",
      },
      -- Quick actions
      {
        "<leader>jp",
        "<cmd>ChatGPTRun grammar_paper<cr>",
        mode = { "n", "x" },
        desc = "Fix Grammar(paper)",
      },
      {
        "<leader>js",
        "<cmd>ChatGPTRun grammar_simple_fix<cr>",
        mode = { "n", "x" },
        desc = "Fix Grammar(simple)",
      },
      { "<leader>jr", "<cmd>ChatGPTRun grammar_rewrite<cr>", mode = { "n", "x" }, desc = "Rewrite" },
      {
        "<leader>jc",
        "<cmd>ChatGPTRun continue_writing<cr>",
        mode = { "n", "x" },
        desc = "Continue writing",
      },
      { "<leader>jt", "<cmd>ChatGPTRun translate<cr>", mode = { "n", "x" }, desc = "Translate" },
      {
        "<leader>jL",
        function()
          P(require("chatgpt.api").last_params)
        end,
        mode = { "n", "x" },
        desc = "Last call parameter",
      },
      {
        "<leader>jC",
        set_context,
        mode = { "n", "x" },
        desc = "set context(up)",
      },
      -- { "<leader>G", group="ChatGPT" },  -- TODO: why this does not work
    },
  },

  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    -- opts = {
    --   -- add any opts here
    -- },
    opts = function(_, opts)
      -- opts["vendors"] = {
      --   ollama = {
      --     __inherited_from = "openai",
      --     api_key_name = "",
      --     endpoint = "http://127.0.0.1:11434/v1",
      --     -- model = "deepseek-coder:33b",
      --     model = "qwen2.5-coder:32b",
      --   },
      -- }
      -- local cred = require("extra_fea.utils").get_cred("gpt-o4-mini.1.gpg")
      -- local cred = require("extra_fea.utils").get_cred("gpt-o3-mini.1.gpg")
      -- local cred = require("extra_fea.utils").get_cred("gpt-o4-mini.gpg")
      local cred = require("extra_fea.utils").get_cred("gpt-4.1.gpg")
      -- local cred = require("extra_fea.utils").get_cred()
      if cred.type == "azure" then
        opts["provider"] = "azure"
        opts["azure"] = {
          endpoint = cred.api_base, -- example: "https://<your-resource-name>.openai.azure.com"
          deployment = cred.model, -- Azure deployment name (e.g., "gpt-4o", "my-gpt-4o-deployment")
          temperature = 1, -- this is used with gpt-reasoning models
        }
        if cred.model == "gpt-4o" then
          opts["azure"].max_tokens = 3000
        end
        if cred.model == "4o-mini" then
          opts["azure"].temperature = 1 -- this is used with gpt-reasoning models
          opts["azure"].reasoning_effort = "low"
        end
        vim.env.AZURE_OPENAI_API_KEY = cred.api_key
      else
        opts["provider"] = "openai"
        opts["openai"] = {
          endpoint = cred.api_base,
          model = cred.model,
        }
        vim.env.OPENAI_API_KEY = cred.api_key
      end
      opts.hints = { enabled = false } -- it is annoying due to conflict with simplegpt.nvim. I have to use <leader>uE to erase them
      opts.auto_suggestions_provider = opts["provider"]

      -- opts["provider"] = "ollama"
      -- opts.auto_suggestions_provider = "ollama"
    end,
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
  { -- I use this plugin just for its bleeding fast auto-completion
    -- I don't use the config in LazyNvim due to binding it with completion plugins does not work well.
    -- Comparison on reddit:
    -- - https://www.reddit.com/r/neovim/comments/1cq9fpp/supermaven_vs_codeium/
    -- - https://www.reddit.com/r/ChatGPTCoding/comments/1du7m6s/supermaven_10_with_1_million_token_context_window/
    -- - https://processwire.com/talk/topic/30101-looking-for-an-ai-assistant-for-code-consider-supermaven/
    "supermaven-inc/supermaven-nvim",
    -- config = function()
    --   require("supermaven-nvim").setup({})
    -- end,
    opts = {
      color = {
        suggestion_color = "#ffaaaa",
        cterm = 244,
      }
    },
  },
}

local extra_m = {
  -- dir = "~/deploy/tools.py/simplegpt.nvim/",
  url = "git@github.com:you-n-g/simplegpt.nvim",
  dependencies = {
    "you-n-g/jinja-engine.nvim",
    {
      "yetone/avante.nvim",
      -- "jackMort/ChatGPT.nvim",
      -- Please check the detailed config above
      -- event = "VeryLazy",
      -- config = true,
      -- dependencies = {
      --   "MunifTanjim/nui.nvim",
      --   "nvim-lua/plenary.nvim",
      --   "folke/trouble.nvim",
      --   "nvim-telescope/telescope.nvim",
      -- },
    },
    "ibhagwan/fzf-lua",
  },
  opts = {
    -- new_tab = true,
    dialog = {
      -- I don't add `"<C-c>", "<esc>" ` due to that it can easily errorously quit the dialog
      keymaps = {
        exit_keys = { "q" },
      },
    },
    keymaps = {
      shortcuts = {
        prefix = "<m-g>",
      },
      prefix = "<m-g><m-g>",
      resume_dialog = { suffix = "<m-g>" },
      custom_shortcuts = {
        ["<m-g>Q"] = {
          mode = { "n", "v" },
          tpl = "question_cn.json",
          target = "chat",
          opts = { noremap = true, silent = true, desc = "Questions for article" },
        },
        -- ["<m-g>D"] = {
        --   mode = { "n", "v" },
        --   tpl = "dictionary_en2cn.json",
        --   target = "popup",
        --   opts = { noremap = true, silent = true, desc = "dictionary_en2cn" },
        -- },
        -- ["<localleader>st"] = {
        --   mode = { "v" },
        --   tpl = "converter.json",
        --   target = "diff",
        --   opts = { noremap = true, silent = true, desc = "Convert between YAML & JSON" },
        -- },
        -- ["<m-g>t"] = {
        --   mode = { "t"},
        --   tpl = "terminal.json",
        --   target = "popup",
        --   opts = { noremap = true, silent = true, desc = "Terminal Command" },
        -- },
      },
    },
    custom_template_path = "~/deploy/configs/lazynvim/data/tpl/",
    tpl_conf = {
      context_len = 20,
    },
  },
  event = "VeryLazy", -- greatly boost the initial of neovim
}

if extra_m.dir == nil or vim.fn.isdirectory(vim.fn.expand(extra_m["dir"])) == 1 then
  table.insert(modules, extra_m)
end
return modules
