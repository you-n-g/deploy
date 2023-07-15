return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    -- Even lazy vim has already config opts as a table, we can still override it by implementing a function.
    opts = function(_, opts)
      -- I rarely use split. But I often need too seed a file in the window
      opts.window.mappings["s"] = "none"
      opts.window.mappings["S"] = "none"
      opts.window.mappings["Y"] = function(state)
        local node = state.tree:get_node()
        local content = node.path
        -- relative
        -- local content = node.path:gsub(state.path, ""):sub(2)
        vim.fn.setreg('"', content)
        vim.fn.setreg("1", content)
        vim.fn.setreg("+", content)
        print("Copied Path: " .. content)
      end
    end,
  },
}
