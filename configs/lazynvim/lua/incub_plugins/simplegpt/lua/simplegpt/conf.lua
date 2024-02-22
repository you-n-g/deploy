M = {
  options  = {},
  defaults = {
    dialog = {
      -- The shortcuts to close a dialog
      exit_keys = {
        "q", "<C-c>", "<esc>"
      },
    },
    -- shortcuts to actions: directly loading specific template and sent to target
    shortcuts = {
      {
        mode = { "n", "v" },
        key = "<LocalLeader>sr",
        tpl = "complete_writing_replace.json",
        target = "popup",
        opts = { noremap = true, silent = true, desc = "Rewrite Text" },
      },
      {
        mode = { "n", "v" },
        key = "<LocalLeader>sc",
        tpl = "code_complete.json",
        target = "popup",
        opts = { noremap = true, silent = true, desc = "Complete Code" },
      },
      {
        mode = { "n", "v" },
        key = "<LocalLeader>sg",
        tpl = "fix_grammar.json",
        target = "diff",
        opts = { noremap = true, silent = true, desc = "Fix grammar" },
      },
      {
        mode = { "n", "v" },
        key = "<LocalLeader>sd",
        tpl = "condensing.json",
        target = "popup",
        opts = { noremap = true, silent = true, desc = "Condense" },
      },
    }
  }
}


function M.setup(options)
  options = options or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, options)
end

return M
