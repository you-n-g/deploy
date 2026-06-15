
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

-- Some project worktrees contain generated sandboxes or FUSE-backed directories
-- that are correctly ignored by Git, but still very expensive to enumerate.
-- Neo-tree normally asks `git status --ignored=traditional` so it can decorate
-- ignored paths. In those repos, that command may still walk into ignored trees
-- and freeze the file explorer.
--
-- A repo can opt into the safer behavior by creating this marker file:
--   .neotree-no-ignored-status
--
-- When the marker exists, only Neo-tree's git-status command is changed from
-- `--ignored=traditional` to `--ignored=no`. Git ignore rules still apply; this
-- just stops Neo-tree from asking Git to list ignored paths for UI decoration.
local function repo_has_marker(root, marker)
  local uv = vim.uv or vim.loop
  return uv.fs_stat(root .. "/" .. marker) ~= nil
end

local function disable_ignored_status_for_marked_repos(args)
  if not repo_has_marker(args.git_root, ".neotree-no-ignored-status") then
    return
  end

  for i, arg in ipairs(args.status_args) do
    if arg:match("^%-%-ignored=") then
      args.status_args[i] = "--ignored=no"
      return
    end
  end
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

      opts.event_handlers = opts.event_handlers or {}
      table.insert(opts.event_handlers, {
        event = "before_git_status",
        id = "disable_ignored_status_for_marked_repos",
        handler = disable_ignored_status_for_marked_repos,
      })

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
