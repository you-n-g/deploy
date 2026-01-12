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

-- local default_azure_model = "azure-gpt-5.2-chat"  -- still slow
-- local default_azure_model = "azure-gpt-5-chat"  -- it is fast
local default_azure_model = "azure-gpt-5.1-chat" -- fast enough

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

  -- it does not work with reasoning models.   Now we have simplegpt.nvim's buffer support.
  -- {
  --   "robitx/gp.nvim",
  --   -- event = "VeryLazy",
  --   lazy = true,
  --   cmd = "GpChatNew",
  --   config = function()
  --       local cred = require("extra_fea.utils").get_cred("gpt-4.1.gpg")
  --       -- local model = require("extra_fea.utils").get_llm_model() or cred.model
  --       local model = cred.model
  --       local conf = {
  --         providers = {
  --             -- For customization, refer to Install > Configuration in the Documentation/Readme
  --           azure = {
  --             disable = false,
  --             endpoint = cred.api_base .. "/openai/deployments/{{model}}/chat/completions?api-version=2025-01-01-preview",
  --             secret = cred.api_key,
  --           },
  --         },
  --         default_chat_agent = "gpt-4.1-ChatBot",
  --         agents = {
  --           {
  --             provider = "azure",
  --             name = "gpt-4.1-ChatBot",
  --             chat = true,
  --             command = false,
  --             -- string with model name or table with model name and parameters
  --             model = { model = model, temperature = 1.1, top_p = 1 },
  --             -- system prompt (use this to specify the persona/role of the AI)
  --             system_prompt = require("gp.defaults").chat_system_prompt,
  --           },
  --         }
  --       }
  --       require("gp").setup(conf)
  --
  --       -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
  --   end,
  -- },

  -- {
  --   "jackMort/ChatGPT.nvim",
  --   branch = "main",
  --   event = "VeryLazy",
  --   config = function()
  --     local action_path
  --     if vim.fn.has("win32") ~= 1 then
  --       action_path = vim.fn.expand("$HOME") .. "/.config/nvim/lua/plugins/action.json"
  --     else
  --       action_path = vim.fn.expand("$LOCALAPPDATA") .. "/nvim/lua/plugins/action.json"
  --     end
  --     -- P(action_path)
  --     local opts = {
  --       -- set it to shift+enter
  --       -- table get or set values
  --       edit_with_instructions = {
  --         keymaps = {
  --           use_output_as_input = "<c-a>", -- sw(a)p. <c-i> is expand as tab in my terminal
  --           -- yank_last = "<c-e>", -- accept , <c-y> is occupied by accept;  this does not work..
  --           -- accept = "<c-e>", -- this will not make yank_last work in <c-y>
  --         },
  --       },
  --       popup_layout = {
  --         center = {
  --           width = "99%",
  --           height = "99%",
  --         },
  --       },
  --       actions_paths = { action_path },
  --     }
  --     if vim.fn.has("win32") ~= 1 then
  --       local cred = require("extra_fea.utils").get_cred("gpt-4.1.gpg")  -- override by gpt-4o later.
  --       if cred.type == "azure" then
  --         vim.env.OPENAI_API_TYPE = cred.type
  --         vim.env.OPENAI_API_BASE = cred.api_base
  --         -- vim.env.OPENAI_API_AZURE_ENGINE = cred.model
  --         vim.env.OPENAI_API_AZURE_ENGINE = "gpt-4o" -- more advanced models  is not supported by ChatGPT.nvim
  --         vim.env.OPENAI_API_KEY = cred.api_key
  --         -- vim.env.OPENAI_API_AZURE_ENGINE = "o3-mini" -- cred.model
  --         -- vim.env.OPENAI_API_AZURE_VERSION = "2024-12-01-preview"
  --       else
  --         vim.env.OPENAI_API_KEY = cred.api_key
  --         vim.env.OPENAI_API_HOST = cred.api_base
  --       end
  --       -- require("extra_fea.utils").export_cred_env()
  --     end
  --     require("chatgpt").setup(opts)
  --     -- config whick key with ["<leader><tab>"] = { name = "+tabs & windows" },
  --     -- require("which-key").register({
  --     --   ["<leader>"] = {
  --     --     ["G"] = { name = "ChatGPT" },
  --     --   },
  --     -- })
  --     require("which-key").add({
  --       { "<leader>G", group = "ChatGPT" },
  --     })
  --   end,
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "folke/trouble.nvim",
  --     "nvim-telescope/telescope.nvim",
  --   },
  --   keys = {
  --     -- it costs money, so G is used..
  --     { "<leader>Gt", "<cmd>ChatGPT<cr>", mode = { "n", "x" }, desc = "Toggle GPT" },
  --     { "<leader>Gg", "<cmd>ChatGPTRun grammar_correction<cr>", mode = { "n", "x" }, desc = "Fix Grammar" },
  --     {
  --       "<leader>Gc",
  --       "<cmd>ChatGPTCompleteCode<cr>",
  --       mode = { "n", "x" },
  --       desc = "Code Complete",
  --     },
  --     { "<leader>Gr", ":ChatGPTRun ", mode = { "n", "x" }, desc = "GPT Run" },
  --     { "<leader>Ga", "<cmd>ChatGPTActAs<cr>", mode = { "n", "x" }, desc = "GPT Act As" },
  --     {
  --       "<leader>Ge",
  --       "<cmd>ChatGPTEditWithInstructions<cr>",
  --       mode = { "n", "x" },
  --       desc = "GPT Instruct Edit",
  --     },
  --     -- Quick actions
  --     {
  --       "<leader>jp",
  --       "<cmd>ChatGPTRun grammar_paper<cr>",
  --       mode = { "n", "x" },
  --       desc = "Fix Grammar(paper)",
  --     },
  --     {
  --       "<leader>js",
  --       "<cmd>ChatGPTRun grammar_simple_fix<cr>",
  --       mode = { "n", "x" },
  --       desc = "Fix Grammar(simple)",
  --     },
  --     { "<leader>jr", "<cmd>ChatGPTRun grammar_rewrite<cr>", mode = { "n", "x" }, desc = "Rewrite" },
  --     {
  --       "<leader>jc",
  --       "<cmd>ChatGPTRun continue_writing<cr>",
  --       mode = { "n", "x" },
  --       desc = "Continue writing",
  --     },
  --     { "<leader>jt", "<cmd>ChatGPTRun translate<cr>", mode = { "n", "x" }, desc = "Translate" },
  --     {
  --       "<leader>jL",
  --       function()
  --         P(require("chatgpt.api").last_params)
  --       end,
  --       mode = { "n", "x" },
  --       desc = "Last call parameter",
  --     },
  --     {
  --       "<leader>jC",
  --       set_context,
  --       mode = { "n", "x" },
  --       desc = "set context(up)",
  --     },
  --     -- { "<leader>G", group="ChatGPT" },  -- TODO: why this does not work
  --   },
  -- },

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
      -- local cred = require("extra_fea.utils").get_cred("gpt-4.1.gpg")
      local cred = require("extra_fea.utils").get_cred("gpt.gpg")
      local model = require("extra_fea.utils").get_llm_model() or cred.model

      opts["providers"] = opts["providers"] or {}
      if vim.env.APIBACKEND == "openai" then
        local provider_name = "openai-" .. vim.env.CHAT_MODEL
        opts["providers"][provider_name] = {
          __inherited_from = "openai",
          endpoint = vim.env.OPENAI_BASE_URL,
          model = vim.env.CHAT_MODEL,
        }
        if vim.env.CHAT_MODEL == "gpt-5" then
          opts["providers"][provider_name].extra_request_body = {
            reasoning_effort = "low"
          }
        end
        opts["provider"] = provider_name
        -- the key will be in vim.env.OPENAI_API_KEY
      elseif cred.type == "azure" then

        -- -- main provider
        -- local azure_provider = {
        --   endpoint = cred.api_base, -- example: "https://<your-resource-name>.openai.azure.com"
        --   -- deployment = model, -- Azure deployment name (e.g., "gpt-4o", "my-gpt-4o-deployment")
        --   deployment = model, -- Azure deployment name (e.g., "gpt-4o", "my-gpt-4o-deployment")
        --   model = model, -- this is just for display purpose in AvanteModels
        --   extra_request_body = {
        --     temperature = 1, -- this is used with gpt-reasoning models
        --   }
        -- }
        -- if model == "gpt-4o" then
        --   azure_provider.max_tokens = 3000
        -- end
        -- if model == "4o-mini" then
        --   azure_provider.extra_request_body = {
        --     temperature = 1, -- this is used with gpt-reasoning models
        --   }
        --   azure_provider.reasoning_effort = "low"
        -- end
        -- opts["providers"]["azure"] = azure_provider
        vim.env.AZURE_OPENAI_API_KEY = cred.api_key

        -- other providers
        local models = {
          { "o4-mini", 1, nil },
          { "gpt-5-chat", 1, 16384 },
          { "gpt-5.2-chat", 1, 16384 },
          { "gpt-4.1", nil, 16384 },
          { "gpt-5", 1, 16384 },
          { "gpt-5.1", 1, 16384 },
          { "gpt-5.1-chat", 1, 16384 },
          { "gpt-5.2", 1, 16384 },
          { "gpt-5-mini", 1, nil },
        }
        for _, m in ipairs(models) do
          local name, temperature, max_tokens = m[1], m[2], m[3]
          opts["providers"]["azure-" .. name] = {
            __inherited_from = "azure",
            endpoint = cred.api_base,
            deployment = name,
            model = name, -- this is just for display purpose in AvanteModels
            extra_request_body = {
              temperature = temperature,
              max_completion_tokens = max_tokens,
            },
          }
        end

        -- opts["provider"] = "azure"
        opts["provider"] = default_azure_model
        -- opts["provider"] = "azure-gpt-5"
      end
      opts.hints = { enabled = false } -- it is annoying due to conflict with simplegpt.nvim. I have to use <leader>uE to erase them
      opts.selection = {
        enabled = true,
        -- hint_display = "delayed",
        hint_display = "none",
      }
      opts.auto_suggestions_provider = opts["provider"]

      -- opts["provider"] = "ollama"
      -- opts.auto_suggestions_provider = "ollama"

      -- opts.debug = true -- not enough information, even the failed request will not show the error message.
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
  -- NOTE: after testing.
  -- I found codeium.nvim is too slow when compared with supermaven.
  -- The <c-l> and <c-j> are not working well due to it always change the following content.
  -- Finally, I found using virtual text with supermaven and blink code with codeium.nvim is the best.
  -- {
  --   "Exafunction/windsurf.nvim",
  --   dependencies = {
  --       "nvim-lua/plenary.nvim",
  --       "hrsh7th/nvim-cmp",
  --   },
  --   config = function()
  --       require("codeium").setup({
  --         -- Optionally disable cmp source if using virtual text only
  --         enable_cmp_source = false,
  --         virtual_text = {
  --             enabled = true,
  --
  --             -- These are the defaults
  --
  --             -- Set to true if you never want completions to be shown automatically.
  --             manual = false,
  --             -- A mapping of filetype to true or false, to enable virtual text.
  --             filetypes = {},
  --             -- Whether to enable virtual text of not for filetypes not specifically listed above.
  --             default_filetype_enabled = true,
  --             -- How long to wait (in ms) before requesting completions after typing stops.
  --             idle_delay = 75,
  --             -- Priority of the virtual text. This usually ensures that the completions appear on top of
  --             -- other plugins that also add virtual text, such as LSP inlay hints, but can be modified if
  --             -- desired.
  --             virtual_text_priority = 65535,
  --             -- Set to false to disable all key bindings for managing completions.
  --             map_keys = true,
  --             -- The key to press when hitting the accept keybinding but no completion is showing.
  --             -- Defaults to \t normally or <c-n> when a popup is showing. 
  --             accept_fallback = nil,
  --             -- Key bindings for managing completions in virtual text mode.
  --             key_bindings = {
  --                 -- Accept the current completion.
  --                 accept = "<Tab>",
  --                 -- Accept the next word.
  --                 accept_word = "<c-l>",
  --                 -- Accept the next line.
  --                 accept_line = "<c-j>",
  --                 -- Clear the virtual text.
  --                 clear = false,
  --                 -- Cycle to the next completion.
  --                 next = "<M-]>",
  --                 -- Cycle to the previous completion.
  --                 prev = "<M-[>",
  --             }
  --         }
  --     })
  --   end
  -- },

  { -- I use this plugin just for its bleeding fast auto-completion
    -- I don't use the config in LazyNvim due to binding it with completion plugins does not work well.
    -- Comparison on reddit:
    -- - https://www.reddit.com/r/neovim/comments/1cq9fpp/supermaven_vs_codeium/
    -- - https://www.reddit.com/r/ChatGPTCoding/comments/1du7m6s/supermaven_10_with_1_million_token_context_window/
    -- - https://processwire.com/talk/topic/30101-looking-for-an-ai-assistant-for-code-consider-supermaven/
    -- Cons:
    -- - Already join cursor: https://www.cursor.com/en/blog/supermaven
    "supermaven-inc/supermaven-nvim",
    -- config = function()
    --   require("supermaven-nvim").setup({})
    -- end,
    opts = {
      color = {
        suggestion_color = "#ffaaaa",
        cterm = 244,
      },
      keymaps = {
        accept_suggestion = "<C-a>",  -- the original mapping is inserting the last input.
        -- clear_suggestion = "<C-]>",
        -- accept_word = "<C-j>",
      },
      ignore_filetypes = { bigfile=true },
    },
    event = "VeryLazy",
    dependencies = {
      {
        "saghen/blink.cmp",
        opts = {
          completion = {
            ghost_text = {
              enabled = false, -- We leave the ghost text for supermaven.
            },
           menu = {
             direction_priority = { 'n', 's' }, -- make the menu appear above  current has higher priority incase of multiple line auto-completion experience
           },
          },
        },
      },
    },
    -- Alternatives:
    -- - codeium/windsurf
  },

  -- NOTE: nearly perfect. Just a little slower than supermaven.
  -- Advantage:
  -- - Better inline completion. It is real insertion, instead of just replace the whole remaining line.
  -- - More switchable choices.
  -- - More shortcuts like accept line.
  -- {
  --   "monkoose/neocodeium",
  --   event = "VeryLazy",
  --   config = function()
  --     local neocodeium = require("neocodeium")
  --     neocodeium.setup()
  --     -- Keymaps to match windsuf/codeium.nvim default AI accept keys
  --     vim.keymap.set("i", "<C-a>", function()
  --         -- use `neocodeium.visible()` to check if we should accept the suggestion or fallback to normal <TAB>
  --         if require("neocodeium").visible() then
  --           require("neocodeium").accept()
  --         else
  --           vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-a>", true, false, true), "n", false)
  --         end
  --     end)
  --     vim.keymap.set("i", "<C-l>", function()
  --         require("neocodeium").accept_line()
  --     end)
  --     vim.keymap.set("i", "<C-j>", function()
  --         require("neocodeium").accept_word()
  --     end)
  --     vim.keymap.set("i", "<M-]>", function()
  --         require("neocodeium").cycle_or_complete()
  --     end)
  --     vim.keymap.set("i", "<M-[>", function()
  --         require("neocodeium").cycle_or_complete(-1)
  --     end)
  --     -- Optionally clear the virtual text with <C-c>, like windsuf
  --     vim.keymap.set("i", "<C-c>", function()
  --         require("neocodeium").clear()
  --     end)
  --     -- Set the highlight group for NeoCodeiumSuggestion like the commented config in supermaven.
  --     vim.api.nvim_set_hl(0, "NeoCodeiumSuggestion", { fg = "#ffaaaa", ctermfg = 244, italic = true }) -- match supermaven suggestion color
  --
  --   end,
  --   dependencies = {
  --     {
  --       "saghen/blink.cmp",
  --       opts = {
  --         completion = {
  --           ghost_text = {
  --             enabled = false, -- We leave the ghost text for supermaven.
  --           },
  --           menu = {
  --             direction_priority = { 'n', 's' },
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },

  -- {
  --   -- this plugin will be good for apply diff to code.
  --   'echasnovski/mini.diff',
  --   version = '*',
  --   opts = {
  --     -- source = "save",
  --   },
  --   -- require"mini.diff".toggle_overlay(vim.api.nvim_get_current_buf())
  -- }

  -- {
  --   "GeorgesAlkhouri/nvim-aider",
  --   cmd = "MyAider",
  --   aider_cmd = "myaider",
  --   -- Example key mappings for common actions:
  --   keys = {
  --     { "<leader>a/", "<cmd>Aider toggle<cr>", desc = "Toggle Aider" },
  --     { "<leader>as", "<cmd>Aider send<cr>", desc = "Send to Aider", mode = { "n", "v" } },
  --     { "<leader>ac", "<cmd>Aider command<cr>", desc = "Aider Commands" },
  --     { "<leader>ab", "<cmd>Aider buffer<cr>", desc = "Send Buffer" },
  --     { "<leader>a+", "<cmd>Aider add<cr>", desc = "Add File" },
  --     { "<leader>a-", "<cmd>Aider drop<cr>", desc = "Drop File" },
  --     { "<leader>ar", "<cmd>Aider add readonly<cr>", desc = "Add Read-Only" },
  --     { "<leader>aR", "<cmd>Aider reset<cr>", desc = "Reset Session" },
  --     -- Example nvim-tree.lua integration if needed
  --     { "<leader>a+", "<cmd>AiderTreeAddFile<cr>", desc = "Add File from Tree to Aider", ft = "NvimTree" },
  --     { "<leader>a-", "<cmd>AiderTreeDropFile<cr>", desc = "Drop File from Tree from Aider", ft = "NvimTree" },
  --   },
  --   dependencies = {
  --     "folke/snacks.nvim",
  --     --- The below dependencies are optional
  --     "catppuccin/nvim",
  --     "nvim-tree/nvim-tree.lua",
  --     --- Neo-tree integration
  --     {
  --       "nvim-neo-tree/neo-tree.nvim",
  --       opts = function(_, opts)
  --         -- Example mapping configuration (already set by default)
  --         -- opts.window = {
  --         --   mappings = {
  --         --     ["+"] = { "nvim_aider_add", desc = "add to aider" },
  --         --     ["-"] = { "nvim_aider_drop", desc = "drop from aider" }
  --         --     ["="] = { "nvim_aider_add_read_only", desc = "add read-only to aider" }
  --         --   }
  --         -- }
  --         require("nvim_aider.neo_tree").setup(opts)
  --       end,
  --     },
  --   },
  --   config = true,
  -- }
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
        {
          key = "<m-g>Q",
          mode = { "n", "v" },
          tpl = "question_cn.json",
          target = "chat",
          opts = { noremap = true, silent = true, desc = "Questions for article" },
        },
        -- ["<m-g>R"] = {  -- gr will conflict with goto reference in LSP.
        --   mode = { "n", "v" },
        --   tpl = "complete_writing_replace.json",
        --   target = "diff",
        --   reg = {
        --     f = "No extra explanations. No block quotes. Output only the rewritten text. Maintain prefix spaces and indentations.",  -- NOTE: can't import due to recurive import
        --   },
        --   opts = { noremap = true, silent = true, desc = "(R)ewrite Text in Diff" },
        -- },
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
        -- { --- Merged into the Plugin.
        --   key = "<m-g>v",
        --   mode = { "v", "n" },
        --   tpl = "variable_explain.json",
        --   target = "popup",
        --   opts = { noremap = true, silent = true, desc = "Add Doc For (V)ariable" },
        -- },
        -- {
        --   key = "<m-g>k",
        --   mode = { "v" },
        --   tpl = "code_complete.json",
        --   target = "diff",
        --   opts = { noremap = true, silent = true, desc = "Add Do(c) For Function" },
        -- },
      },
    },
    custom_template_path = "~/deploy/configs/lazynvim/data/tpl/",
    tpl_conf = {
      context_len = 20,
      content_max_len = 500, -- the max number of lines to show as full content
    },
    buffer_chat = {
      -- provider = "azure-o4-mini"
      -- provider = "azure-gpt-5"
      -- provider = "azure-gpt-5-mini"
	    -- provider = "azure-gpt-5-chat", -- (preferred)
	    -- provider = "azure-gpt-4.1", -- if we want super long context and prefer fast response.
      provider = vim.env.APIBACKEND == "openai" and "openai-" .. vim.env.CHAT_MODEL or default_azure_model,
    },
  },
  event = "VeryLazy", -- greatly boost the initial of neovim
}

if extra_m.dir == nil or vim.fn.isdirectory(vim.fn.expand(extra_m["dir"])) == 1 then
  table.insert(modules, extra_m)
end
return modules
