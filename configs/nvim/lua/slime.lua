


local M = {}

function M.reset_slime()
    if vim.api.nvim_get_var("slime_target") == "neovim" then
        if vim.o.filetype == "toggleterm" then
            vim.api.nvim_set_var("slime_last_channel", vim.o.channel)
        else
            local ok, last_channel = pcall(vim.api.nvim_get_var, "slime_last_channel")
            if ok then
                vim.api.nvim_buf_set_var(0, "slime_config", {jobid=last_channel})
            end
        end
    end
end

return M
