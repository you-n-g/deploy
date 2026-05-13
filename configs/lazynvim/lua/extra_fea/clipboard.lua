local has_tmux = vim.fn.executable("tmux") == 1 and vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
local has_xclip = vim.fn.executable("xclip") == 1

if not (has_tmux and has_xclip) then
  return
end

-- Refresh DISPLAY from tmux global env before each xclip call,
-- so long-running nvim instances survive SSH reconnects.
local refresh = [[
display="$(tmux show-environment -g DISPLAY 2>/dev/null | sed -n 's/^DISPLAY=//p')"
if [ -n "$display" ]; then
  export DISPLAY="$display"
fi
]]

vim.g.clipboard = {
  name = "tmux-copy-xclip-paste",
  copy = {
    ["+"] = { "tmux", "load-buffer", "-w", "-" },
    ["*"] = { "bash", "-c", refresh .. " xclip -selection primary -loops 0 -in" },
  },
  paste = {
    ["+"] = { "bash", "-c", refresh .. " xclip -selection clipboard -out -target UTF8_STRING" },
    ["*"] = { "bash", "-c", refresh .. " xclip -selection primary -out -target UTF8_STRING" },
  },
  cache_enabled = 0,
}
