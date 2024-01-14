-- require('plenary.reload').reload_module('simplegpt')
-- print(123123)

-- reload simplegpt without plenary
-- package.loaded['simplegpt'] = nil
-- P(require('simplegpt'))
-- lua P(vim.fn.getpos("'<"), vim.fn.getpos("'>"))
-- lua P(vim.fn.getpos("'<"))
-- lua P(vim.api.nvim_buf_get_mark(0, '<'), vim.api.nvim_buf_get_mark(0, '>'))
-- print("haha")
-- print("Good")

--
-- local Popup = require("nui.popup")
-- local Layout = require("nui.layout")
--
-- local popup_one, popup_two = Popup({
--   enter = true,
--   border = "single",
-- }), Popup({
--   border = "double",
-- })
--
-- local layout = Layout(
--   {
--     position = "50%",
--     size = {
--       width = 80,
--       height = "60%",
--     },
--   },
--   Layout.Box({
--     Layout.Box(popup_one, { size = "40%" }),
--     Layout.Box(popup_two, { size = "60%" }),
--   }, { dir = "row" })
-- )
--
-- local current_dir = "row"
--
-- popup_one:map("n", "r", function()
--   if current_dir == "col" then
--     layout:update(Layout.Box({
--       Layout.Box(popup_one, { size = "40%" }),
--       Layout.Box(popup_two, { size = "60%" }),
--     }, { dir = "row" }))
--
--     current_dir = "row"
--   else
--     layout:update(Layout.Box({
--       Layout.Box(popup_two, { size = "60%" }),
--       Layout.Box(popup_one, { size = "40%" }),
--     }, { dir = "col" }))
--
--     current_dir = "col"
--   end
-- end, {})
--
-- layout:mount()


-- Popup to get sth 
-- local Popup = require("nui.popup")
-- local event = require("nui.utils.autocmd").event
--
-- local popup = Popup({
--   enter = true,
--   focusable = true,
--   border = {
--     style = "rounded",
--   },
--   position = "50%",
--   size = {
--     width = "80%",
--     height = "60%",
--   },
-- })
--
-- -- mount/open the component
-- popup:mount()
--
-- -- unmount component when cursor leaves buffer
-- popup:on(event.BufLeave, function()
--   popup:unmount()
-- end)
--
-- -- set content
-- vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { "Hello World" })

local M = {}

function M.setup()
  require"simplegpt.mappings".setup()
end

return M
