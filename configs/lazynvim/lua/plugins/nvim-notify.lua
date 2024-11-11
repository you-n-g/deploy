-- if true then
--   return {}
-- end

-- this is only for change the position of notification
-- https://github.com/rcarriga/nvim-notify/issues/94
-- The key difference is stages_util.DIRECTION.BOTTOM_UP & anchor = "SW"

local opts = { -- this is copy from static
  stages = {
    function(state)
      local next_height = state.message.height + 2
      local stages_util = require("notify.stages.util")
      -- local next_row = stages_util.available_slot(state.open_windows, next_height, stages_util.DIRECTION.BOTTOM_UP)
      local next_row = stages_util.available_slot(state.open_windows, next_height, stages_util.DIRECTION.BOTTOM_UP)
      -- local next_row = stages_util.available_slot(state.open_windows, next_height, stages_util.DIRECTION.LEFT_RIGHT)
      -- local next_row = stages_util.available_slot(state.open_windows, next_height, stages_util.DIRECTION.RIGTH_LEFT)
      if not next_row then
        return nil
      end
      return {
        relative = "editor",
        anchor = "NE",
        width = state.message.width,
        height = state.message.height,
        col = vim.opt.columns:get(),
        row = next_row,
        border = "rounded",
        style = "minimal",
      }
    end,
    function()
      return {
        col = vim.opt.columns:get(),
        time = true,
      }
    end,
  },
}

return {
  -- {
  --   "rcarriga/nvim-notify",
  --   -- opts = opts,
  --   opts = {
  --     top_down = false,
  --   }
  -- },
  {
    "folke/snacks.nvim",
    opts = {
      notifier = {
        top_down = false,
      },
    },
  },
}
