local M = {}

-- Create a command named `New`; it is similar to `new`
-- But it will create a new buffer with the same filetype with current buffer
-- Create a new buffer with the same filetype as the current buffer
function M.new_buffer_same_filetype(cmd)
    local btype = vim.bo.filetype

    -- Create a new buffer
    vim.cmd(cmd)

    -- Set the new buffer's filetype to the current buffer's filetype
    vim.bo.filetype = btype
end

-- Create a command named `New`
vim.cmd([[command! New lua require"extra_fea.shortcut_cmd".new_buffer_same_filetype("new")]])

vim.cmd([[command! ENew lua require"extra_fea.shortcut_cmd".new_buffer_same_filetype("enew")]])

return M
