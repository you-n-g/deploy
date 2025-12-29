--[[
This is a plugin that shows tips based on current condition.
--]]

NAV_TIPS = [[
For marking sections you are focusing on, you can use following registers:
- q: question
- a: AI command blocks
- e: explanation
- r: runnable code]]

-- if file name is nav.md, show above tips
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "nav.md",
  callback = function()
    vim.keymap.set("n", "<localleader>t", function()
      vim.notify(NAV_TIPS, vim.log.levels.INFO, { title = "Nav Tips" })
    end, { buffer = true, desc = "Show Nav Tips" })
  end,
})
