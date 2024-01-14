local M = {}

function M.to_clipboard()
  local rqa = require"simplegpt.tpl".RegQAUI()
  rqa:build(function (question)
    for _, reg in ipairs({'"', '+'}) do
      vim.fn.setreg(reg, question)
    end
    print("content sent to clipboard.")
  end)
end

return M
