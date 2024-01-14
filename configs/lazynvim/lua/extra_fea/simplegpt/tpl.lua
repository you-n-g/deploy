-- This module provides features to presenting the templates, placeholders.
local Popup = require("nui.popup")
local Layout = require("nui.layout")
local dialog = require("extra_fea.simplegpt.dialog")
local utils = require("extra_fea.simplegpt.utils")
-- TODO:
local M = {}
M.RegQAUI = utils.class("RegQAUI", dialog.BaseDialog) -- register-based UI

function M.RegQAUI:ctor()
  self.super:ctor()
  -- P(self.all_pops)
  if "" == vim.fn.getreg("t") then
    vim.fn.setreg("t", [[Context:```{{c}}```, {{q}}, {{i}}, Please input your answer:```]])
  end
end

function M.get_tpl()
  return vim.fn.getreg("t")
end

--- This function retrieves all placeholders from a template stored in a vim register "t".
--- Placeholders are defined as any text enclosed in double curly braces, e.g., "{{placeholder}}".
--- For example, if the template is "Hello, {{name}}!", the function will return a table containing "name".
--- @return table: A table containing all placeholders found in the template.
function M.get_placeholders()
  local template = M.get_tpl()

  -- find all the placeholders
  local keys = {}
  for key in template:gmatch("%{%{(.-)%}%}") do
    table.insert(keys, key)
  end
  return keys
end


function M.RegQAUI:build()
  local pops = {}
  for _, reg_key in ipairs(M.get_placeholders()) do
    pops[reg_key] = vim.fn.getreg(reg_key)
  end

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

  -- register keys for all pops
  -- merge tpl_pop and pop_dict
  table.insert(self.all_pops, tpl_pop)
  for _, v in pairs(pop_dict) do
    table.insert(self.all_pops, v)
  end
  self:register_keys()
  -- - save the registers: This applies to only the register template
  -- TODO: auto update register
  for _, pop in ipairs(self.all_pops) do
    pop:map("n", { "<c-s>" }, function()
      vim.fn.setreg("t", table.concat(vim.api.nvim_buf_get_lines(tpl_pop.bufnr, 0, -1, true), "\n"))
      for k, p in pairs(pop_dict) do
        vim.fn.setreg(k, table.concat(vim.api.nvim_buf_get_lines(p.bufnr, 0, -1, true), "\n"))
      end
      print("Register updated.")
    end, { noremap = true })
  end

  -- create boxes and layout
  local boxes = { Layout.Box(tpl_pop, { ["size"] = size .. "%" }) }

  for _, v in pairs(pop_dict) do
    table.insert(boxes, Layout.Box(v, { ["size"] = size .. "%" }))
  end

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
end

function M.RegQAUI:get_q()
  local function interp(s, tab)
    return (s:gsub('({{%l}})', function(w) return tab[w:sub(3, -3)] or w end))
  end
  local ph_keys = {}
  for _, k in ipairs(M.get_placeholders()) do
    ph_keys[k] = vim.fn.getreg(k)
  end
  return interp(M.get_tpl(), ph_keys)
end


-- local rqa = M.RegQAUI()
-- rqa:build()
-- print(rqa:get_q())
return M
