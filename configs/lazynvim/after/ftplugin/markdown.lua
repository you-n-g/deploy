vim.api.nvim_set_hl(0, "MarkdownExplainCodeMarker", { fg = "#61AFEF", bold = true })
vim.api.nvim_set_hl(0, "MarkdownExplainRunMarker", { fg = "#E5C07B", bold = true })
vim.api.nvim_set_hl(0, "MarkdownReviewBugMarker", { fg = "#FF6B6B", bold = true })

local buf = vim.api.nvim_get_current_buf()
local group = vim.api.nvim_create_augroup("markdown-explain-markers-" .. buf, { clear = true })

local function add_matches()
  if vim.api.nvim_get_current_buf() ~= buf or vim.bo.filetype ~= "markdown" then
    return
  end

  local key = "markdown_explain_marker_matches_" .. buf
  for _, id in ipairs(vim.w[key] or {}) do
    pcall(vim.fn.matchdelete, id)
  end

  vim.w[key] = {
    vim.fn.matchadd("MarkdownExplainCodeMarker", "󰅩", 20),
    vim.fn.matchadd("MarkdownExplainRunMarker", "󰄉", 20),
    vim.fn.matchadd("MarkdownReviewBugMarker", "", 20),
  }
end

add_matches()

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  group = group,
  callback = add_matches,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    vim.api.nvim_set_hl(0, "MarkdownExplainCodeMarker", { fg = "#61AFEF", bold = true })
    vim.api.nvim_set_hl(0, "MarkdownExplainRunMarker", { fg = "#E5C07B", bold = true })
    vim.api.nvim_set_hl(0, "MarkdownReviewBugMarker", { fg = "#FF6B6B", bold = true })
    add_matches()
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  buffer = buf,
  callback = function()
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end,
})
