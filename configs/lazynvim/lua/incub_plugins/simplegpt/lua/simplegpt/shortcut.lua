-- We should add some shortcuts for nvim telescope

-- TODO: require config

local loader = require("simplegpt.loader")

M = {}
local conf = {
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
  },
}

function M.build_func(t)
  return function()
    local rqa = require("simplegpt.tpl").RegQAUI()
    -- the context when building the QA builder
    local context = {
      filetype = vim.bo.filetype,
      rqa = rqa,
    }
    -- rqa will build the question and send to the target
    rqa:build(require("simplegpt.target." .. t).build_q_handler(context))
  end
end

M.register_shortcuts = function()
  for _, s in ipairs(conf.shortcuts) do
    vim.keymap.set(s.mode, s.key, function()
      loader.load_reg(s.tpl)
      M.build_func(s.target)()
    end, s.opts)
  end
end


return M
