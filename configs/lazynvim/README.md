# LazyVim 的主要目的
- 考虑多系统的兼容性：因为之前的设计没有考虑这边的windows 配置，所以导致在windows下没法直接用（得进一步设计）；  还不如趁机会 参考一下其他人的 config的设计
- 跟进一下最新大家常用的plugins:   每次跟进大家的新插件的时候，对比&配置都会消耗巨大的时间。

# 开始的安装

- `:LazyExtras` + `<x>`  来开启或者关闭一些plugins;
  - 可以通过配置 import来启动，或者手动启动

# 使用Plugins的一些notes

直接DEBUG neovim instance in lua
- 主要思路来自 https://github.com/jbyuki/one-small-step-for-vimkind/blob/main/doc/osv.txt#L44
- 先开一个instance `<leader>daL` 开启server (如果没有的话，就`:lua require"osv".launch({port=8086})`)
  - 后来改成 `<leader>dL`
- 再开第二个个instance
  - 打开相关代码`<leader>db`设置断点 
  - continue run `<leader>dc` (选择attach到 neovim instance 8086)
- 操作第一个instance，触发第二个instance设定的断点

DEBUG 一些异常的行为
- 按键开始还按期望行为， 然后失灵: `<space>sk` 看看keymapping的变化(同一个key可能会有很多种映射)

# 还希望要的功能
- [ ] LSP in other documents. `https://github.com/jmbuhr/otter.nvim`
- [X] fast wrap (类似 https://github.com/jiangmiao/auto-pairs), 但是 "echasnovski/mini.pairs" 没有提供类似的功能
- [ ] strip spaces in selection in vim (to better apply GPT to specific scope)
- [ ] [Auto-Import can be invoke actively](https://github.com/neovim/nvim-lspconfig/issues/1122), [Another](https://neovim.discourse.group/t/how-can-i-trigger-the-auto-import/636)
- [X] Try documentation generation, sometimes doge-gen does not work well.. https://github.com/danymat/neogen
- [ ] renaming folder in neotree in Python project: https://github.com/alexpasmantier/pymple.nvim

- [ ] Attach to a docker dap-server: maybe we can replace the project prefix or creating link?



# Introduction
The neovim configuration is based on LazyVim and may be useful for Python users. In addition to the raw LazyVim, the following features and plugins have been added.


- [Python-LSP](lua/plugins/nvim-lspconfig.lua)
  - Pyright, Full formatting and range formatting,

# Usage
## Maintainance
- 默认的行为已经很好了，不要轻易调整(默认config变动，可能会花大量的时间测试)；调整时注明详细的原因

## Debug
- 注释掉所有plugins, 看看行为是否正常

# Manual Tasks

```bash
# We should follow next steps
# 1. https://github.com/enterprises/microsoft
# 2. `:Copilot auth`, and then open https://github.com/login/device for authentication
#   - sometimes it does not work (on my WSL of my borrowed equipment) due to unknown issues.
```
