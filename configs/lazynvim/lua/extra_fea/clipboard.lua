local has_tmux = vim.fn.executable("tmux") == 1 and vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
local has_xclip = vim.fn.executable("xclip") == 1

-- Refresh DISPLAY from tmux global env before each xclip call,
-- so long-running nvim instances survive SSH reconnects.
local refresh = [[
display="$(tmux show-environment -g DISPLAY 2>/dev/null | sed -n 's/^DISPLAY=//p')"
if [ -n "$display" ]; then
  export DISPLAY="$display"
fi
]]

local tmux_copy = { "tmux", "load-buffer", "-w", "-" }
local xclip_copy = {
  ["+"] = { "bash", "-c", refresh .. " xclip -selection clipboard -loops 0 -in" },
  ["*"] = { "bash", "-c", refresh .. " xclip -selection primary -loops 0 -in" },
}
local xclip_paste = {
  ["+"] = { "bash", "-c", refresh .. " xclip -selection clipboard -out -target UTF8_STRING" },
  ["*"] = { "bash", "-c", refresh .. " xclip -selection primary -out -target UTF8_STRING" },
}

local clipboard = {
  name = "tmux-copy-xclip-paste",
  cache_enabled = 0,
}

if has_tmux then
  clipboard.copy = {
    ["+"] = tmux_copy,
    ["*"] = tmux_copy,
  }
else
  clipboard.copy = xclip_copy
end

if has_xclip then
  clipboard.paste = xclip_paste
end

if clipboard.copy and clipboard.paste then
  vim.g.clipboard = clipboard
end
