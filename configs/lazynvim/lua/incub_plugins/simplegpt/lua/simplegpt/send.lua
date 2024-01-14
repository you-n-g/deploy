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

function M.to_chatgpt()
  local rqa = require"simplegpt.tpl".RegQAUI()
  rqa:build(function (question)
    local chat_api = require"chatgpt.flows.chat"
    chat_api:open()
    local bufnr = chat_api.chat.chat_input.bufnr
    -- remove all content in bufnr and set the content to quesetion
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(question, "\n"))

    -- set bufnr to normal mode
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_command([[normal! \<Esc>]])
    print("content sent to chatgpt.")
  end)
end

return M
