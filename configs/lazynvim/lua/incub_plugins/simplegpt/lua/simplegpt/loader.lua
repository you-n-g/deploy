-- Dump and load questions from disks.

-- TODO:  store data here partially
-- vim.fn.stdpath("data") .. "/config-local",

local tpl_api = require("simplegpt.tpl")

local script_path = (debug.getinfo(1, "S").source:sub(2))
local script_dir = vim.fn.fnamemodify(script_path, ":h")
local data_path = script_dir .. "/../../qa_tpls/"

-- Dump the contents of multiple registers to a file
local M = {}

function M.dump_reg(fname)
  local reg_values = {}
  local registers = tpl_api.get_placeholders("%l") -- only dump the registers with single letter. Placehodlers like {{q-}} will not be dumped
  table.insert(registers, "t")
  for _, reg in ipairs(registers) do
    reg_values[reg] = vim.fn.getreg(reg)
  end
  local file = io.open(data_path .. fname, "w")
  if file ~= nil then
    file:write(vim.fn.json_encode(reg_values)) -- {indent = true} does not work...
    file:close()
    print("Registers dumped successfully")
  end
end

function M.input_dump_name()
  local Input = require("nui.input")
  local event = require("nui.utils.autocmd").event

  local input = Input({
    position = "50%",
    size = {
      width = 40,
    },
    border = {
      style = "single",
      text = {
        top = "Filename(ignore `.json` suffix)",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    prompt = "> ",
    default_value = "new_template",
    on_submit = function(value)
      local fname = value .. ".json"
      M.dump_reg(fname)
      print("Saved: " .. fname)
    end,
  })

  -- mount/open the component
  input:mount()

  -- unmount component when cursor leaves buffer
  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

-- Load the contents from a file into multiple registers
function M.load_reg(fname)
  local file = io.open(data_path .. fname, "r")
  if file ~= nil then
    local contents = file:read("*all")
    file:close()
    local reg_values = vim.fn.json_decode(contents)
    if reg_values ~= nil then
      for reg, value in pairs(reg_values) do
        vim.fn.setreg(reg, value)
      end
      print("Registers loaded successfully")
    end
  end
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

function M.tele_load_reg()
  require("telescope.builtin").find_files({
    cwd = data_path,
    previewer = true,
    attach_mappings = function(_, map)
      map("i", "<CR>", function(prompt_bufnr)
        local selection = action_state.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)
        M.load_reg(selection.value)
      end)
      return true
    end,
  })
end

return M
