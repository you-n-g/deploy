local function copy_path(type)
  local function _copy(state)
      local node = state.tree:get_node()
      local content
      if type == "P" then
        -- absolute path
        content = node.path
      end
      if type == "p" then
        -- relative path
        content = node.path:gsub(state.path, ""):sub(2)
      end
      if type == "n" then
        -- Only file name
        content = vim.fn.fnamemodify(node.path, ":t")
      end
      vim.fn.setreg('"', content)
      vim.fn.setreg("1", content)
      vim.fn.setreg("+", content)
      print("Copied Path: " .. content)
  end
  return _copy
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    -- Even lazy vim has already config opts as a table, we can still override it by implementing a function.
    opts = function(_, opts)
  
      -- Remove some shortcuts
      -- I rarely use split. But I often need too seak a file in the window
      opts.window.mappings["s"] = "none"
      opts.window.mappings["S"] = "none"

      -- Add some extra features.
      -- opts.commands = vim.tbl_extend("force", opts.commands, {""})  -- to make it a named function.
      -- NOTE:
      -- `Y` is already mapped to copy_file_name, So we don't need to override it.
      -- But it does not work on my case. So I create a more comprehensive solution.
      opts.window.mappings["YP"] = copy_path("P")
      opts.window.mappings["Yp"] = copy_path("p")
      opts.window.mappings["Yn"] = copy_path("n")
    end,
  },
}
