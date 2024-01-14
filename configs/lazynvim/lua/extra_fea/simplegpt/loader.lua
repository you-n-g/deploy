-- Dump and load questions from disks.

-- TODO:  store data here
-- vim.fn.stdpath("data") .. "/config-local",

local tpl_api = require"extra_fea.simplegpt.tpl"

-- Dump the contents of multiple registers to a file
local M = {}

function M.dump_reg()
  local reg_values = {}
  local registers = tpl_api.get_placeholders()
  table.insert(registers, "t")
  for _, reg in ipairs(registers) do
    reg_values[reg] = vim.fn.getreg(reg)
  end
  local file = io.open("register_dump.json", "w")
  if file ~= nil then
    file:write(vim.fn.json_encode(reg_values))
    file:close()
  end
end

-- Load the contents from a file into multiple registers
function M.load_reg()
  local file = io.open("register_dump.json", "r")
  if file ~= nil then
    local contents = file:read("*all")
    file:close()
    local reg_values = vim.fn.json_decode(contents)
    for reg, value in pairs(reg_values) do
      vim.fn.setreg(reg, value)
    end
  end
end

return M
