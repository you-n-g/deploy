# LazyVim 的主要目的
- 考虑多系统的兼容性：因为之前的设计没有考虑这边的windows 配置，所以导致在windows下没法直接用（得进一步设计）；  还不如趁机会 参考一下其他人的 config的设计
- 跟进一下最新大家常用的plugins:   每次跟进大家的新插件的时候，对比&配置都会消耗巨大的时间。


# 使用Plugins的一些notes

直接DEBUG neovim instance in lua
- 主要思路来自 https://github.com/jbyuki/one-small-step-for-vimkind
- 先开一个instance `<leader>daL` 开启server
- 再开第二个个instance
  - 打开相关代码`<leader>db`设置断点 
  - continue run `<leader>dc`
- 操作第一个instance，触发第二个instance设定的断点

# 还希望要的功能
[ ] - fast wrap (类似 https://github.com/jiangmiao/auto-pairs), 但是 "echasnovski/mini.pairs" 没有提供类似的功能



# Introduction
The neovim configuration is based on LazyVim and may be useful for Python users. In addition to the raw LazyVim, the following features and plugins have been added.


- [Python-LSP](lua/plugins/nvim-lspconfig.lua)
  - Pyright, Full formatting and range formatting,
