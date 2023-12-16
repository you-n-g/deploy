-- TODO:
-- - Will the selected message be sent when we start chatting?
-- NOTE: 
-- - Minimal shortcuts: https://github.com/jackMort/ChatGPT.nvim#interactive-popup 

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
    -- "jackMort/ChatGPT.nvim",
    "you-n-g/ChatGPT.nvim",
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
        actions_paths = {action_path},
      }
      if vim.fn.has("win32") ~= 1 then
        local api_base = vim.fn.system("gpg -q --decrypt " .. vim.fn.expand("$HOME") .. "/deploy/keys/gpt4.gpg | sed -n 1p")
        local azure_engine = vim.fn.system("gpg -q --decrypt " .. vim.fn.expand("$HOME") .. "/deploy/keys/gpt4.gpg | sed -n 2p")
        local api_key = vim.fn.system("gpg -q --decrypt " .. vim.fn.expand("$HOME") .. "/deploy/keys/gpt4.gpg | sed -n 3p")

        vim.fn.execute("let $OPENAI_API_TYPE='azure'")
        vim.fn.execute("let $OPENAI_API_BASE='" .. api_base .. "'")
        vim.fn.execute("let $OPENAI_API_AZURE_ENGINE='" .. azure_engine .. "'")
        vim.fn.execute("let $OPENAI_API_KEY='" .. api_key .. "'")
      end
      require("chatgpt").setup(opts)
      -- config whick key with ["<leader><tab>"] = { name = "+tabs & windows" },
      require("which-key").register({
        ["<leader>"] = {
          ["G"] = { name = "ChatGPT" },
        },
      })
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      -- it costs money, so G is used..
      { "<leader>Gt", "<cmd>ChatGPT<cr>", mode = { "n", "x" }, desc = "Toggle GPT" },
      { "<leader>Gg", "<cmd>ChatGPTRun grammar_correction<cr>", mode = { "n", "x" }, desc = "Fix Grammar" },
      { "<leader>Gc", "<cmd>ChatGPTCompleteCode<cr>", mode = { "n", "x" }, desc = "Code Complete" },
      { "<leader>Gr", ":ChatGPTRun ", mode = { "n", "x" }, desc = "GPT Run" },
      { "<leader>Ga", "<cmd>ChatGPTActAs<cr>", mode = { "n", "x" }, desc = "GPT Act As" },
      { "<leader>Ge", "<cmd>ChatGPTEditWithInstructions<cr>", mode = { "n", "x" }, desc = "GPT Instruct Edit" },
      -- Quick actions
      { "<leader>jp", "<cmd>ChatGPTRun grammar_paper<cr>", mode = { "n", "x" }, desc = "Fix Grammar(paper)", },
      { "<leader>js", "<cmd>ChatGPTRun grammar_simple_fix<cr>", mode = { "n", "x" }, desc = "Fix Grammar(simple)", },
      { "<leader>jr", "<cmd>ChatGPTRun grammar_rewrite<cr>", mode = { "n", "x" }, desc = "Rewrite", },
      { "<leader>jc", "<cmd>ChatGPTRun continue_writing<cr>", mode = { "n", "x" }, desc = "Continue writing", },
      { "<leader>jt", "<cmd>ChatGPTRun translate<cr>", mode = { "n", "x" }, desc = "Translate", },
      { "<leader>jL", function () P(require"chatgpt.api".last_params) end, mode = { "n", "x" }, desc = "Last call parameter", },
      { "<leader>jC", set_context, mode = { "n", "x" }, desc = "set context(up)", },
    },
  },
}

local extra_m = {
  dir = "~/repos/simple-gpt.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}

if vim.fn.isdirectory(vim.fn.expand(extra_m["dir"])) == 1 then
  table.insert(modules, extra_m)
end

return modules
