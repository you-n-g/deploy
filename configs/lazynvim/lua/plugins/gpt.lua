-- TODO:
-- - Will the selected message be sent when we start chatting?
return {
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    config = function()
      local opts = {
        -- set it to shift+enter
        -- table get or set values
        edit_with_instructions = {
          keymaps = {
            use_output_as_input = "<c-a>", -- sw(a)p. <c-i> is expand as tab in my terminal
          },
        },
      }
      if vim.fn.has("win32") ~= 1 then
        opts["api_key_cmd"] = "gpg --decrypt ~/deploy/keys/gpt.gpg 2>/dev/null"
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
    },
  },
}
