-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Force python filetype for files with 'uv run ... python' shebang
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*",
  callback = function()
    -- Get the first line of the buffer
    local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
    -- Check if it matches the complex uv run shebang
    if first_line:match("^#!.*uv run .*python") then
      vim.bo.filetype = "python"
    end
  end,
})
