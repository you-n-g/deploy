local has_display = vim.env.DISPLAY ~= nil and vim.env.DISPLAY ~= ""
local has_xclip = vim.fn.executable("xclip") == 1

if not (has_display and has_xclip) then
  return
end

vim.g.clipboard = {
  name = "xclip-x11-forward",
  copy = {
    ["+"] = "xclip -quiet -in -selection clipboard",
    ["*"] = "xclip -quiet -in -selection primary",
  },
  paste = {
    ["+"] = "xclip -out -selection clipboard",
    ["*"] = "xclip -out -selection primary",
  },
  cache_enabled = 0,
}
