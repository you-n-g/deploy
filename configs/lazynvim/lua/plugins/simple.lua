-- simple plugins are added here
-- NOTE: if the plugins become longer, then please move it into seperate file
-- - 如何对插件做一个合理的分类?
--   - editor,coding(这两者的区别是什么，是和编程语言的语义相关吗？)
--   - ui(有的功能虽然表现出来了UI，但是还有很多别的功能)
-- TODO:
-- https://github.com/archibate/nvim-gpt + EdgeGPT
-- hot chatgpt plugins: https://github.com/jackMort/ChatGPT.nvim
-- Comparision related repos: https://github.com/search?q=gpt%20nvim&type=repositories

return {
  {
    -- It can't attach to a specific buffer and run code in another one
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
          require("luapad").toggle()
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
      { "<leader>ren", [[<esc>}o<CR><c-u># %%<esc>o<esc>0"_C]], desc = "Create next cell" },
      -- NOTE: 有时候会有自动缩进，而且缩进的时候还会给写一些注释前缀，所以要多出一个动作来清理这一行
    },
  },
  {
    "neovim/nvim-lspconfig",
    -- opts = { servers = {ruff_lsp = {}} },  -- ruff_lsp will not git docs
    keys = {
      {
        --- 解决了 pyright 慢的问题后，这里显得不是很有必要
        "<leader>cD",
        function()
          -- 因为 pyright 太慢了，所以这里搞了一个deatch的功能
          local bufnr = vim.api.nvim_get_current_buf()
          -- local clients = vim.lsp.buf_get_clients(bufnr)
          local clients = vim.lsp.get_active_clients()
          for client_id, cli in pairs(clients) do
            -- vim.lsp.buf_detach_client(bufnr, client_id)
            if cli.name == "pyright" then
              vim.lsp.buf_detach_client(bufnr, client_id)
            end
          end
        end,
        desc = "Detach the LSP from cur buffer",
      },
    },
    opts = { servers = { pyright = {} } },
    -- mason will automatically load the lsp server

    -- TIPS:
    -- https://github.com/microsoft/pyright/blob/main/docs/configuration.md
    -- 如果觉得pyright启动很慢，把他的子目录都去掉 (你觉得显示的 diagnostics 不需要覆盖的目录都去掉)
    -- pyrightconfig.json:
    -- { "exclude": [ "**/__pycache__", "data/", "libs/", "intermediate/", "scripts/" ] }
  },
  {
    "mg979/vim-visual-multi",
    -- BEGIN 'mg979/vim-visual-multi' -----------------------------------------
    -- 不记得了就多复习 vim -Nu ~/.vim/plugged/vim-visual-multi/tutorialrc
    --
    -- 反vimer直觉的
    -- 复制粘贴
    -- - 有时候normal模式下x剪切，再<c-v>粘贴会没用; extend模式d删除，然后在<c-v>粘贴我这边能work
    -- - <c-v> 才是那个每行都有差异的粘贴， p会粘贴一样的东西
    -- v选择编辑的操作会出错，得用extend模式代替v
    -- s不是删除然后立马插入，而是进入到一个selecting模式
    -- 选取了多行后 \\c 可以创建多个normal模式的光标，\\a可以创建多个extend模式的光标
    -- - <C-up>  <C-down> 之类的功能也能达到类似的效果，目前和和kitty的transparency的功能冲突了
    --
    -- 有用的功能: https://github.com/mg979/vim-visual-multi/blob/master/doc/vm-tutorial
    -- - 在<c-n>时， \\w 可以切换是否要boundary,  \\c 可以切换是否要 case-sensitive
    -- - 在visual mode 选择cursor时，m是一个标记操作符， mG 代表从当前标记到结尾
    --
    -- 优势
    -- - 和用macro记录改一波再应用到别的位置作对比，
    --   用我可以同时看到改这些是怎么变化的
    -- - 快速替换一些word和标点
    -- - 将一堆赋值替换成 tuple
    --
    -- BUG
    -- - 后来好像 <C-v> <C-up>等等ctrl开头的功能好像不管用了。。。后面发现是tmux的问题
    --
    -- END   'mg979/vim-visual-multi' -----------------------------------------
  },
  {
    -- 这个功能的preview功能似乎还是有bug
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = { { "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline" } },
    config = true,
  },
  -- {
  --   -- 因为是lazy加载的，所以开始没有打开任何文件时用会报错
  --   "lukas-reineke/indent-blankline.nvim",
  --   config = function(_, opts)
  --     require("indent_blankline").setup(opts)
  --     print(vim.g.indent_blankline_buftype_exclude)
  --     local t = vim.g.indent_blankline_buftype_exclude
  --     table.insert(t, "qf")
  --     vim.g.indent_blankline_buftype_exclude = t
  --   end,
  -- },
  {
    "dhruvasagar/vim-table-mode",
  },
}
