-- if true then
--   return {}
-- end

-- this is only for change the position of notification
-- https://github.com/rcarriga/nvim-notify/issues/94
-- The key difference is stages_util.DIRECTION.BOTTOM_UP & anchor = "SW"

local opts = {
  stages = {
    function(state)
      local stages_util = require("notify.stages.util")
      local next_height = state.message.height + 2
      local next_row = stages_util.available_slot(state.open_windows, next_height, stages_util.DIRECTION.BOTTOM_UP)
      if not next_row then
        return nil
      end
      return {
        relative = "editor",
        -- anchor = "NE",
        anchor = "SW", --  非常奇怪，这里会让提示信息从右下角往上方再提高一点;  虽然不是按字面意义跑，但是也能达到想要的效果
        width = state.message.width,
        height = state.message.height,
        col = vim.opt.columns:get(),
        row = next_row,
        border = "rounded",
        style = "minimal",
        opacity = 0,
      }
    end,
    function()
      return {
        opacity = { 100 },
        col = { vim.opt.columns:get() },
      }
    end,
    function()
      return {
        col = { vim.opt.columns:get() },
        time = true,
      }
    end,
    function()
      return {
        width = {
          1,
          frequency = 2.5,
          damping = 0.9,
          complete = function(cur_width)
            return cur_width < 3
          end,
        },
        opacity = {
          0,
          frequency = 2,
          complete = function(cur_opacity)
            return cur_opacity <= 4
          end,
        },
        col = { vim.opt.columns:get() },
      }
    end,
  },
}
return {
  {
    "rcarriga/nvim-notify",
  },
}
