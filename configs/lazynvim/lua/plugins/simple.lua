-- simple plugins are added here
-- NOTE: if the plugins become longer, then please move it into seperate file
return {
  {
    "rafcamlet/nvim-luapad",
    keys = {
      {
        "<leader>Li",
        function()
          require("luapad").init()
          -- It seems that this is not working
          -- require("luapad").attach({
          --   context = {
          --     return_4 = function()
          --       return 4
          --     end,
          --   },
          -- })
        end,
        -- "<cmd>Luapad<cr>",
        mode = "n",
        desc = "Luapad",
      },
      {
        "<leader>Lr",
        function()
          require("luapad").toggle({
            context = {
              return_4 = function()
                return 4
              end,
            },
          })
        end,
        -- "<cmd>LuaRun<cr>",
        mode = "n",
        desc = "Toggle Current buffer to Luapad",
      },
    },
    -- TODO: attach to current buffer
  },
  {
    "untitled-ai/jupyter_ascending.vim",
    -- 这种模式我非常喜欢，但是现在还有不足的地方
    -- - 它运行cell的时候感觉位置不对, 等待这个错误的解决
    --   https://github.com/untitled-ai/jupyter_ascending.vim/issues/8
    -- - 后来又试了一次，卡在新问题上了
    --   https://github.com/untitled-ai/jupyter_ascending/issues/44
    -- - 最后终于解决,见 deploy_apps/install_fav_py_pack.sh
    -- TODO:
    -- - Please align the keymap to the REPL
    keys = {
      {
        "<leader>rx",
        "<Plug>JupyterExecute",
        desc = "Execute Cell",
      },
      {
        "<leader>rR",
        "<Plug>JupyterRestart",
        desc = "Restart Kernel",
      },
      { "<leader>ren", "<esc>}o<CR><c-u># %%<esc>o<esc>0C", desc = "Create next cell" },
      -- NOTE: 有时候会有自动缩进，而且缩进的时候还会给写一些注释前缀，所以要多出一个动作来清理这一行
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = { servers = {pyright = {}} },
    -- mason will automatically load the lsp server
  },
}
