-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- load the confs for a specific features that not a plugin (thus does not suite lazy.vim)
local function load_extra_feature()
  local dir_name = "extra_fea"
  local feature_dir = vim.fn.stdpath("config") .. "/lua/" .. dir_name
  local features = vim.fn.glob(feature_dir .. "/*.lua", true, true)

  for _, plugin in ipairs(features) do
    local m = require(dir_name .. "." .. vim.fn.fnamemodify(plugin, ":t:r"))
    -- print(dir_name .. "." .. vim.fn.fnamemodify(plugin, ":t:r"), m)
  end
end

load_extra_feature()
