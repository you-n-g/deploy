-- global functions

--- It will stop at the first nil
---@vararg: all kinds of variable yo want to inspect
function P(...)
  local args = {...}
  for i, v in ipairs(args) do
    print("Arg:", i)
    print(vim.inspect(v))
  end
end

-- TODO: get comprehensive information of current status.

