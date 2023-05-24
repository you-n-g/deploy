return {
  { "nvim-neo-tree/neo-tree.nvim",
    -- Even lazy vim has already config opts as a table, we can still override it by implementing a function.
    opts = function(_, opts)
      -- I rarely use split. But I often need too seed a file in the window
      opts.window.mappings['s'] = 'none'
      opts.window.mappings['S'] = 'none'
    end
  },
}
