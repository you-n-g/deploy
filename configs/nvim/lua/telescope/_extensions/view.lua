-- 
-- 这个脚本卡在了下面的地方
-- - 怎么在lua中列出所有的 variable name
-- - 怎么在lua中跑等效于 let 的变量
local pickers = require("telescope.pickers")
local conf = require'telescope.config'.values
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local actions_set = require'telescope.actions.set'
local action_state = require("telescope.actions.state")


local function view(opts)
    opts = opts or {}
    local contents = {}
    vt = {'g', 'b', 'w', 't', 'v', 'env'}
    -- vim["g"].loaded_nerdtree_autoload w
    for k, v in pairs(vt) do
        print(vim.inspect(vim[v]))
        for key, val in pairs(vim[v]) do
            print(k .. ":" .. key .. " -- " .. val)
            table.insert(contents, k .. ":" .. key .. " -- " .. val)
        end
    end
    pickers.new(opts, {
        prompt_title = "View Status",
        finder = finders.new_table(contents, opts),
		sorter = conf.generic_sorter(),
        -- previewer = conf.qflist_previewer(opts),
    }):find()
end

return require("telescope").register_extension {
    exports = { view =  view },
}
