-- a globl function
function P(...)
  local args = {...}
  for _, v in ipairs(args) do
    print(vim.inspect(v))
  end
end
