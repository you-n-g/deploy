return {
  -- I don't like the autoformat feature of nvim-lspconfig. It will change the code and produce unexpected git commits.
  {
    "neovim/nvim-lspconfig",
    -- opts = { servers = {ruff_lsp = {}} },  -- ruff_lsp will not git docs
    keys = {
      -- The default config only cover <c-f> & <c-b>; <c-b> conflicts with tmux
      {
        "<c-d>",
        function()
          if not require("noice.lsp").scroll(4) then
            return "<c-d>"
          end
        end,
        silent = true,
        expr = true,
        desc = "Scroll forward",
        mode = { "i", "n", "s" },
      },
      {
        "<c-u>",
        function()
          if not require("noice.lsp").scroll(-4) then
            return "<c-u>"
          end
        end,
        silent = true,
        expr = true,
        desc = "Scroll backward",
        mode = { "i", "n", "s" },
      },
      -- { -- 解决了 pyright 慢的问题后，这里显得不是很有必要
      --   "<leader>cD",
      --   function()
      --     -- 因为 pyright 太慢了，所以这里搞了一个deatch的功能
      --     local bufnr = vim.api.nvim_get_current_buf()
      --     -- local clients = vim.lsp.buf_get_clients(bufnr)
      --     local clients = vim.lsp.get_active_clients()
      --     for client_id, cli in pairs(clients) do
      --       -- vim.lsp.buf_detach_client(bufnr, client_id)
      --       if cli.name == "pyright" then
      --         vim.lsp.buf_detach_client(bufnr, client_id)
      --       end
      --     end
      --   end,
      --   desc = "Detach the LSP from cur buffer",
      -- },
    },
    -- pyink is a python formatter based on black
    opts = { autoformat = false, servers = { pyright = {} } },
    -- mason will automatically load the lsp server

    -- TIPS:
    -- https://github.com/microsoft/pyright/blob/main/docs/configuration.md
    -- 如果觉得pyright启动很慢，把他的子目录都去掉 (你觉得显示的 diagnostics 不需要覆盖的目录都去掉)
    -- pyrightconfig.json:
    -- { "exclude": [ "**/__pycache__", "data/", "libs/", "intermediate/", "scripts/" ] }
  },
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      -- We origianlly want to install debugpy. But it seems not working...
      for _, s in ipairs({}) do
        table.insert(opts["ensure_installed"], s)
      end
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    -- opts = {
    --   -- this does not work...
    --   automatic_installation = { exclude = { "debugpy" } },
    -- },
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      -- this does not work...
      -- automatic_installation = false, --{ exclude = { "debugpy" } },
      -- automatic_installation = false, -- this works
      automatic_installation = { exclude = { "python" } }, -- this works
      -- So, it is language specific.
    },
  },
  {
    "jose-elias-alvarez/null-ls.nvim",
    opts = function(_, opts)
      local nls = require("null-ls")
      -- If we want to config more details, we can write an funciton return similar things...
      -- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/lua/null-ls/builtins/formatting/yapf.lua
      table.insert(
        opts["sources"],
        nls.builtins.formatting.yapf.with({
          extra_args = { "--style={based_on_style: google, column_limit: 120, indent_width: 4}" },
        })
      )
    end,
  },
}
