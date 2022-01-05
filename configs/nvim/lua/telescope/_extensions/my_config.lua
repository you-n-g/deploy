local pickers = require("telescope.pickers")
local conf = require'telescope.config'.values
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local actions_set = require'telescope.actions.set'
local action_state = require("telescope.actions.state")


local function my_config(opts)
    opts = opts or {}
    pickers.new(opts, {
        prompt_title = "My config",
        finder = finders.new_table({"tmux", "clear", "neovim"}, opts),
		sorter = conf.generic_sorter(),
        -- previewer = conf.qflist_previewer(opts),
        attach_mappings = function(prompt_bufnr)
            actions_set.select:replace(function(_, type)
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if entry[1] == "neovim" then
                    vim.api.nvim_set_var("slime_target", "neovim")
                    pcall(vim.api.nvim_buf_del_var, 0, "slime_config")
                    pcall(vim.api.nvim_del_var, "slime_default_config")
                    pcall(vim.api.nvim_del_var, "slime_dont_ask_default")
                end
                if entry[1] == "tmux" then
                    vim.api.nvim_set_var("slime_target", "tmux")
                    pcall(vim.api.nvim_buf_del_var, 0, "slime_config")
                    vim.api.nvim_set_var("slime_default_config", { socket_name = vim.api.nvim_eval("get(split($TMUX, ','), 0)"), target_pane = "{top-right}" })
                    vim.api.nvim_set_var("slime_dont_ask_default", 1)
                end
                if entry[1] == "clear" then
                    pcall(vim.api.nvim_buf_del_var, 0, "slime_config")
                end
            end)
            return true
        end,
    }):find()
end

return require("telescope").register_extension {
    -- setup = function(ext_config)
    --     ctags = ext_config.ctags or {"ctags"}
    --     ft_opt = ext_config.ft_opt or ft_opt_default
    -- end,
    exports = { my_config = my_config },
}
