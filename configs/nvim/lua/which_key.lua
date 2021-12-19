require("which-key").setup {
-- your configuration comes here
-- or leave it empty to use the default settings
-- refer to the configuration section below
  triggers_blacklist = {
    -- list of mode / prefixes that should never be hooked by WhichKey
    -- this is mostly relevant for key maps that start with a native binding
    -- most people should not need to change this
    i = { "j", "k", "<tab>"},
    v = { "j", "k", "<tab>"},
    n = { "\t" }
  }
}


local wk = require("which-key")



wk.register({
  t = {
    name = "Toggle",
    s = { "<cmd>set spell!", 'Spell Toggle' },
    -- [s ]s: previous(next) spell error
    -- zg: 标记为正确词汇
    -- zw: 标记为错误词汇
    -- z=: 可以选择其补全的词汇
    -- zuX: 把 x 从词汇表中删除
    -- 词汇表小写代表修改 spellfile, 大写代表 internal-wordlist
    -- internal-wordlist 代表存在内存中，下次重新打开vim  或者设置 encoding都会导致它消失
    p = { "<cmd>exec '!sed -n  '.line('w0').','.line('w$').'p %'<cr>", 'Plain text'  },
    n = { "<cmd>NERDTreeToggle<cr>", 'NERDTreeToggle'},
    l = {"<cmd>TagbarToggle<cr>", 'TagbarToggle'},
    c = {"<cmd>Telescope my_config<cr>", 'My Config'},
  },
  p = {
       name = 'IPython Cell',
      r = {'<cmd>IPythonCellRun<cr>', 'Run Script'},
      R = {'<cmd>IPythonCellRunTime<cr>', 'Run script with time'},
      e = {'<cmd>IPythonCellExecuteCellVerbose<cr>', 'Execute Cell'},
      E = {'<cmd>IPythonCellExecuteCellVerboseJump<cr>', 'Execute Cell Jump'},
      l = {'<cmd>IPythonCellClear<cr>', 'Clear'},
      x = {'<cmd>IPythonCellClose<cr>', 'Close'},
      c = {'<cmd>SlimeSend<cr>', 'Send line or selected'},
      p = {'<cmd>IPythonCellPrevCommand<cr>', 'Previous Command'},
      Q = {'<cmd>IPythonCellRestart<cr>', 'restart ipython'},
      t = {'<cmd>SlimeSend1 %load_ext autotime<cr>', 'load autotime'},
      q = {'<cmd>SlimeSend1 exit<cr>', 'exit'},
      k = {'<cmd>IPythonCellPrevCell<cr>', 'Prev Cell'},
      j = {'<cmd>IPythonCellNextCell<cr>', 'Next Cell'},
      d = {
           name = 'debug related',
           d = {'<cmd>SlimeSend1 %debug<cr>', 'debug mode'},
      },
      s = {
           name = 'Send for sh',
           i = {'<cmd>SlimeSend1 ipython --matplotlib<cr>', 'start ipython with matplotlib'},
           }
        -- Failed settings
        -- \'s' : [':SlimeSend1 ipython --matplotlib', 'start ipython with matplotlib'],
        -- \'b' : ['SlimeSend0 "b ".expand("%:p").":".line("$")', 'Send file break point'],
        -- \'e' : ['placehoder', 'Create an embeded env']
      },

  j = {
      name = 'jupyter-vim',
      e = {'<cmd>JupyterSendCell<cr>', 'Jupyter Send Cell'},
      d = {'<cmd>JupyterDisconnect<cr>', 'Jupyter Disconnect'},
  },

  e = {
     name = 'coc-explorer',
    f = {'<cmd>CocCommand explorer --sources=buffer+,file+ --preset floatingRightside<cr>', 'Float Explorer'},
    c = {'<cmd>CocCommand explorer --sources=buffer+,file+<cr>', 'Side Explorer'},
    e = {'<cmd>CocCommand explorer --sources=buffer+,file+ --preset floating<cr>', 'Full Explorer'},
  },

  c = {
     name = 'coc.vim',
     s = {'<cmd><Plug>(coc-convert-snippet)<cr>', 'Convert to Snippets'},
     F = {'<cmd>Format<cr>', 'Format all'},
  },

  l = {
     name = 'coc-list',
    o = {'<cmd>CocList -I --auto-preview --ignore-case --input=outlines lines<cr>', 'Outlines'},
    i = {'<cmd>CocList -I --auto-preview --ignore-case lines<cr>', 'Search in this file'},
    c = {'<cmd>CocList commands<cr>', 'commands'},
    u = {'<cmd>CocList mru<cr>', 'mru(current dir)'},
  },
  L = {
     name = 'lua',
     i = {"<cmd>Luadev<cr>", "lunch"},
     -- c = {"<Plug>(Luadev-RunLine)", "run line"}
  },
  v = {
     name = 'vimspector',
    c = {'<cmd>call vimspector#Continue()<cr>', 'continue'},
    C = {'<cmd>call vimspector#ClearBreakpoints()<cr>', 'clear all breakpoints'},
    S = {'<cmd>call vimspector#Stop()<cr>', 'stop'},
    p = {'<cmd>call vimspector#Pause()<cr>', 'pause'},
    b = {'<cmd>call vimspector#ToggleBreakpoint()<cr>', 'breakpoint toggle'},
    o = {'<cmd>call vimspector#StepOver()<cr>', 'step over'},
    i = {'<cmd>call vimspector#StepInto()<cr>', 'step into'},
    O = {'<cmd>call vimspector#StepOut()<cr>', 'step out'},
    R = {'<cmd>VimspectorReset<cr>', 'reset'},
    r = {'<cmd>call vimspector#RunToCursor()<cr>', 'run to cursor'},
    u = {'<cmd>call vimspector#UpFrame()<cr>', 'Move up call stack'},
    d = {'<cmd>call vimspector#DownFrame()<cr>', 'Move down call stack'},
  },
  f = {
    name = 'fzf & telescope',
    g = {'<cmd>Rg<cr>', 'Rg'},
    G = {'<cmd>Rgc<cr>', 'Rg without filename'},
    l = {'<cmd>BLines<cr>', 'Lines in the current buffer'},
    L = {'<cmd>Lines<cr>', 'Lines in loaded buffer'},
    m = {'<cmd>Telescope marks<cr>', 'Marks'},
    b = {'<cmd>Telescope buffers<cr>', 'Buffers'},
    M = {'<cmd>Maps<cr>', 'Mappings'},
    o = {'<cmd>Lines Outlines<cr>', 'Outlines'},
    h = {'<cmd>Telescope help_tags<cr>', 'help tags'},
    d = {
        name="deploy and cheatsheets",
            g = {'<cmd>execute \'lua require("telescope.builtin").live_grep({search_dirs={"~/deploy/", "~/cheatsheets/code_to_copy/"}})\'<cr>', 'deploy and cheatsheet(live_grep)'},
            f = {'<cmd>execute \'lua require("telescope.builtin").find_files({search_dirs={"~/deploy/", "~/cheatsheets/code_to_copy/"}})\'<cr>', 'deploy and cheatsheet(find_files)'}
         },
        p = {
            name = "plugins",
            g = {'<cmd>RgPlug<cr>', 'plugins(live_grep)'},
            f = {'<cmd>execute \'lua require("telescope.builtin").find_files({search_dirs={"~/.vim/plugged"}})\'<cr>', 'plugins(find_files)'}
        }
     },
-- " 这里可以通过tab选多个，回车后变成quick fix
--
-- " 发现 telescope 还是太慢了， fzf比较快
-- " \'g' : [':execute '''.'lua require("telescope.builtin").live_grep({search_dirs={"~/.vim/plugged"}})'.'''', 'plugins(live_grep)'],
-- " \'dg' : [':execute '''.'lua require("telescope.builtin").live_grep({search_dirs={"~/deploy/", "~/cheatsheets/code_to_copy/"}})'.'''', 'deploy and cheatsheet(live_grep)'],
-- " \'df' : [':execute '''.'lua require("telescope.builtin").find_files({search_dirs={"~/deploy/", "~/cheatsheets/code_to_copy/"}})'.'''', 'deploy and cheatsheet(find_files)']
    h = {
        name = "Git Related",
        l = {'<cmd>G log --graph --oneline --decorate --all<cr>', 'commit tree'},
        h = {'<cmd>0Glog<cr>', 'The commit file of current history'}
    }

}, { prefix = "<leader>" })

wk.register({
  L = {
     name = 'lua',
     c = {"<Plug>(Luadev-RunLine)", "run line"},
  }
}, { prefix = "<leader>", mode = "n"})

wk.register({
  L = {
     name = 'lua',
     c = {"<Plug>(Luadev-Run)", "run selected"}
  }
}, { prefix = "<leader>", mode = "v"})
