local has_display = vim.env.DISPLAY ~= nil and vim.env.DISPLAY ~= ""
local has_xclip = vim.fn.executable("xclip") == 1

if not (has_display and has_xclip) then
  return
end

-- Refresh DISPLAY from tmux session env before each xclip call,
-- so long-running nvim instances survive SSH reconnects.
local refresh = "eval export $(tmux show-env DISPLAY 2>/dev/null);"

vim.g.clipboard = {
  name = "xclip-x11-forward",
  copy = {
    ["+"] = { "bash", "-c", refresh .. " xclip -quiet -in -selection clipboard" },
    ["*"] = { "bash", "-c", refresh .. " xclip -quiet -in -selection primary" },
  },
  paste = {
    ["+"] = { "bash", "-c", refresh .. " xclip -out -selection clipboard" },
    ["*"] = { "bash", "-c", refresh .. " xclip -out -selection primary" },
  },
  cache_enabled = 0,
}
