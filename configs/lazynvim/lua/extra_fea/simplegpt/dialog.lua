local utils = require("extra_fea.simplegpt.utils")

local M = {}
M.BaseDialog = utils.class("BaseDialog")

function M.BaseDialog:ctor()
  self.all_pops = {}
end

function M.BaseDialog:register_keys()
  local all_pops = self.all_pops
  -- set keys to escape for all popups
  -- - Quit
  for _, pop in pairs(all_pops) do
    pop:map("n", { "q", "<C-c>", "<esc>" }, function()
      -- if vim.fn.mode() == "i" then
      --   vim.api.nvim_command("stopinsert")
      -- end
      vim.cmd("q")
    end, { noremap = true })
  end
  -- - cycle windows
  local _closure_func = function(i, sft)
    return function()
      vim.api.nvim_set_current_win(all_pops[(i - 1 + sft) % #all_pops + 1].winid)
    end
  end
  for i, pop in ipairs(all_pops) do
    pop:map("n", { "<tab>" }, _closure_func(i, 1), { noremap = true })
    pop:map("n", { "<S-Tab>" }, _closure_func(i, -1), { noremap = true })
  end
end

return M
