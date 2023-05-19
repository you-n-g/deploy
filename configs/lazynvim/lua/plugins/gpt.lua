return {
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    config = function()
      require("chatgpt").setup()
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
      { "<leader>Gg", "<cmd>ChatGPT<cr>", mode = { "n", "x" }, desc = "toggle GPT" },
      { "<leader>Gc", "<cmd>ChatGPTCompleteCode<cr>", mode = { "n", "x" }, desc = "Code Complete" },
      { "<leader>Gr", ":ChatGPTRun ", mode = { "n", "x" }, desc = "GPT Run" },
      { "<leader>Ga", "<cmd>ChatGPTActAs<cr>", mode = { "n", "x" }, desc = "GPT Act As" },
      { "<leader>Ge", "<cmd>ChatGPTEditWithInstructions<cr>", mode = { "n", "x" }, desc = "GPT Instruct Edit" },
    },
  },
}
