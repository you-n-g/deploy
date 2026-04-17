return {
  { -- the reason of using this:
    -- The code block in the markdown is not very clear.
    'MeanderingProgrammer/render-markdown.nvim',
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },
  {
    'cameron-wags/rainbow_csv.nvim',
    config = true,
    ft = {
        'csv',
        'tsv',
        'csv_semicolon',
        'csv_whitespace',
        'csv_pipe',
        'rfc_csv',
        'rfc_semicolon'
    },
    cmd = {
        'RainbowDelim',
        'RainbowDelimSimple',
        'RainbowDelimQuoted',
        'RainbowMultiDelim'
    }
  },
  {
    'mcauley-penney/visual-whitespace.nvim',
    config = true,
    event = "ModeChanged *:[vV\22]", -- optionally, lazy load on entering visual mode
    opts = {},
  },

  {
    "folke/snacks.nvim",
    opts = {
      styles = {
        notification = {
          wo = {
            -- Fully opaque, no transparency;
            -- Just to ctrl+click can open the window correctly
            winblend = 0,
          },
        },
      },
    }
  },
  {
    'lfv89/vim-interestingwords'
  },
  {
    "iamcco/markdown-preview.nvim",
    -- 只在执行这些命令时才加载插件
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    -- 或者在打开 Markdown 文件时按需加载
    ft = { "markdown" },
    -- 安装或更新插件时自动运行底层的构建脚本
    build = function()
      -- NOTE: 我发现这个好像得事后调用 `call mkdp#util#install()` 才能成功安装
      vim.fn["mkdp#util#install"]()
    end,
    -- 绑定你的专属快捷键 (这里设定为 <leader>mp 也就是 空格+m+p)
    keys = {
      {
        "<leader>mp",
        ft = "markdown",
        "<cmd>MarkdownPreviewToggle<cr>",
        desc = "Toggle Markdown Preview",
      },
    },
    config = function()
      -- 这里可以配置插件的全局变量
      vim.g.mkdp_auto_close = 1 -- 切换 buffer 时自动关闭预览浏览器
      vim.g.mkdp_theme = 'dark' -- 强制使用暗色主题
      if vim.fn.has('linux') == 1 then
        vim.cmd([[
          function! OpenMarkdownPreview(url) abort
            echom '[mkdp] ' . a:url
          endfunction
        ]])
        vim.g.mkdp_browserfunc = 'OpenMarkdownPreview'
        vim.g.mkdp_echo_preview_url = 1
      end
    end,
  },
}
