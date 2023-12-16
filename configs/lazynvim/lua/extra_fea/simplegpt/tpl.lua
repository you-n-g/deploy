-- Tem related tools

local function get_placeholders()
  local template = [[Context:```{{c}}```, {{q}}, {{i}}, Please input your answer:```]]

  -- find all the place hodlers
  local keys = {}
  for key in template:gmatch("%{%{(.-)%}%}") do
    table.insert(keys, key)
  end
  return keys
end

print(get_placeholders())
