-- This module provides features to presenting the templates, placeholders.
local Popup = require("nui.popup")
local Layout = require("nui.layout")
local dialog = require("simplegpt.dialog")
local utils = require("simplegpt.utils")
-- TODO:
local M = {}
M.RegQAUI = utils.class("RegQAUI", dialog.BaseDialog) -- register-based UI

function M.RegQAUI:ctor()
  self.super:ctor()
  self.pop_dict = {}  -- a dict of register to popup
  self.tpl_pop = nil  -- the popup of template
  self.special_dict = self:get_special()  -- we have to get special dict before editing the quesiton.. Ohterwise we'll lose the file and visual selection
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
function M.get_placeholders(enable_special)
  local template = M.get_tpl()

  local reg
  if enable_special ~= nil then
    reg = "%{%{(.-)%}%}"
  else
    reg = "%{%{(%l)%}%}"
  end

  -- find all the placeholders
  local keys = {}
  for key in template:gmatch(reg) do
    table.insert(keys, key)
  end
  return keys
end

function M.RegQAUI:update_reg()
      vim.fn.setreg("t", table.concat(vim.api.nvim_buf_get_lines(self.tpl_pop.bufnr, 0, -1, true), "\n"))
      for k, p in pairs(self.pop_dict) do
        vim.fn.setreg(k, table.concat(vim.api.nvim_buf_get_lines(p.bufnr, 0, -1, true), "\n"))
      end
      print("Register updated.")
end

function M.RegQAUI:build(callback)
  self.pop_dict = {}
  local reg_cnt = 0
  for _, k in ipairs(M.get_placeholders()) do
    self.pop_dict[k] = Popup({
      border = {
        style = "single",
        text = {
          top = "register: {{" .. k .. "}}",
          top_align = "center",
        },
      },
    })
    reg_cnt = reg_cnt + 1
    vim.api.nvim_buf_set_text(self.pop_dict[k].bufnr, 0, 0, 0, 0, vim.split(vim.fn.getreg(k), '\n'))
  end

  local size = math.floor(100 / (reg_cnt + 1))

  self.tpl_pop = Popup({
    enter = true,
    border = {
      style = "double",
      text = {
        top = "Prompt template:",
        top_align = "center",
      },
    },
  })

  vim.api.nvim_buf_set_text(self.tpl_pop.bufnr, 0, 0, 0, 0, vim.split(vim.fn.getreg("t"), '\n'))

  -- merge self.pop_dict and pop_dict
  self.all_pops = {self.tpl_pop}
  for _, v in pairs(self.pop_dict) do
    table.insert(self.all_pops, v)
  end

  self:register_keys(function()
    -- exit callback
    self:update_reg()
    if callback ~= nil then
      callback(self:get_q())
    end
  end
)
  -- - save the registers: This applies to only the register template
  -- TODO: auto update register
  for _, pop in ipairs(self.all_pops) do
    pop:map("n", { "<c-s>" }, function() self:update_reg() end, { noremap = true })
  end

  -- create boxes and layout
  local boxes = { Layout.Box(self.tpl_pop, { ["size"] = size .. "%" }) }

  for _, v in pairs(self.pop_dict) do
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

function M.RegQAUI:get_special()
  local res = {}
  --
  -- 1) all file content
  -- Get the current buffer
  local buf = vim.api.nvim_get_current_buf()
  -- Get the number of lines in the buffer
  local line_count = vim.api.nvim_buf_line_count(buf)
  -- Get all lines
  local lines = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)
  res["content"] = table.concat(lines, "\n")

  -- 2) get the visual content
  local select_pos = require"extra_fea.utils".get_visual_selection()
  local start_line = select_pos["start"]["row"] - 1  -- Lua indexing is 0-based
  local end_line = select_pos["end"]["row"]
  -- Get the selected lines
  lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
  -- Now 'lines' is a table containing all selected lines
  res["visual"] = table.concat(lines, "\n")

  -- Get the filetype of the current buffer
  res["filetype"] = vim.bo.filetype
  return res
end

function M.RegQAUI:get_q()
  local function interp(s, tab)
    return (s:gsub('({{.-}})', function(w) return tab[w:sub(3, -3)] or w end))
  end
  local ph_keys = {}
  for _, k in ipairs(M.get_placeholders()) do
    ph_keys[k] = vim.fn.getreg(k)
  end
  return interp(M.get_tpl(), vim.tbl_extend("force", ph_keys, self.special_dict))
end


-- local rqa = M.RegQAUI()
-- rqa:build()
-- print(rqa:get_q())
return M
