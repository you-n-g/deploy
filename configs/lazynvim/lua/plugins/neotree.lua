
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

local function is_pdf(path)
  return type(path) == "string" and path:lower():match("%.pdf$") ~= nil
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
      opts.window.mappings["Y"] = nil
      -- NOTE:
      -- `Y` is already mapped to copy_file_name, So we don't need to override it.
      -- But it does not work on my case. So I create a more comprehensive solution.
      opts.window.mappings["YP"] = copy_path("P")
      opts.window.mappings["Yp"] = copy_path("p")
      opts.window.mappings["Yn"] = copy_path("n")

      opts.commands = vim.tbl_extend("force", opts.commands or {}, {
        open_smart = function(state)
          local ok, fs_commands = pcall(require, "neo-tree.sources.filesystem.commands")
          if not ok then
            return
          end

          local node = state.tree:get_node()
          if node and node.type == "file" and is_pdf(node.path) and vim.fn.has("mac") == 1 then
            -- Prefer launching the macOS app bundle so it shows up as a real app (Cmd+Tab),
            -- then fall back to the CLI binary if needed.
            local app_name = "Sioyek"
            if vim.fn.executable("open") == 1 then
              -- It is important to use open to launch the app, otherwise I guess it may result in a subprocess of Finder/Terminal?
              vim.fn.system({ "open", "-Ra", app_name })
              if vim.v.shell_error == 0 then
                vim.fn.jobstart({ "open", "-a", app_name, node.path }, { detach = true })
                return
              end
            end

            -- if vim.fn.executable("sioyek") == 1 then
            --   vim.fn.jobstart({ "sioyek", node.path }, { detach = true })
            --   return
            -- end
          end

          fs_commands.open(state)
        end,
      })

      -- Use sioyek to open PDFs on macOS, otherwise keep default open behavior.
      opts.window.mappings["<cr>"] = "open_smart"
      opts.window.mappings["l"] = "open_smart"
    end,
  },
}
