-- This module provides features to presenting the templates, placeholders.
if "" == vim.fn.getreg("t") then
  vim.fn.setreg("t", [[Context:```{{c}}```, {{q}}, {{i}}, Please input your answer:```]])
end

local function get_placeholders()
  local template = vim.fn.getreg("t")

  -- find all the place hodlers
  local keys = {}
  for key in template:gmatch("%{%{(.-)%}%}") do
    table.insert(keys, key)
  end
  return keys
end

local pops = {}

for _, reg_key in ipairs(get_placeholders()) do
  pops[reg_key] = vim.fn.getreg(reg_key)
end


local Popup = require("nui.popup")
local Layout = require("nui.layout")

local pop_dict = {}
local reg_cnt = 0
for k in pairs(pops) do
  pop_dict[k] = Popup({
    border = {
      style = "single",
      text = {
        top = "register: {{" .. k .. "}}",
        top_align = "center",
      },
    },
  })
  reg_cnt = reg_cnt + 1
  vim.api.nvim_buf_set_text(pop_dict[k].bufnr, 0, 0, 0, 0, vim.split(vim.fn.getreg(k), '\n'))
end

local size = math.floor(100 / (reg_cnt + 1))

local tpl_pop = Popup({
  enter = true,
  border = {
    style = "double",
    text = {
      top = "Prompt template:",
      top_align = "center",
    },
  },
})

vim.api.nvim_buf_set_text(tpl_pop.bufnr, 0, 0, 0, 0, vim.split(vim.fn.getreg("t"), '\n'))
local boxes = { Layout.Box(tpl_pop, { ["size"] = size .. "%" }) }

for _, v in pairs(pop_dict) do
  table.insert(boxes, Layout.Box(v, { ["size"] = size .. "%" }))
end

-- merge tpl_pop and pop_dict
local all_pops = { tpl_pop }
for _, v in pairs(pop_dict) do
  table.insert(all_pops, v)
end

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

-- - save the registers
for _, pop in ipairs(all_pops) do
  pop:map("n", { "<c-s>" }, function()
    vim.fn.setreg("t", table.concat(vim.api.nvim_buf_get_lines(tpl_pop.bufnr, 0, -1, true), "\n"))
    for k, p in pairs(pop_dict) do
      vim.fn.setreg(k, table.concat(vim.api.nvim_buf_get_lines(p.bufnr, 0, -1, true), "\n"))
    end
    print("Register updated.")
  end, { noremap = true })
end

-- choose the last window


local layout = Layout(
  {
    position = "50%",
    size = {
      width = "90%",
      height = "90%",
    },
  },
  Layout.Box(boxes, { dir = "col" })
)

layout:mount()
