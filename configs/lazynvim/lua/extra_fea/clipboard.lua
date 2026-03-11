-- NOTE: I found the default value is reasonable enough for me...
-- - in WSL, it automatically uses the system clipboard
-- - on server, it sync with tmux clipboard automatically

if true then
  return 
end
-- 统一系统、tmux、vim的剪切板; 就不需要下面的了
if vim.fn.system('tmux -V') ~= '' then
  -- I prefer the tmux clipboard as "+*" (based on my experience, it is more safety than systemclipboard);
  vim.g.clipboard = {
    name = 'tmux',
    copy = {
      ['+'] = 'tmux load-buffer -w -',
      ['*'] = 'tmux load-buffer -w -',
    },
    paste = {
      ['+'] = 'tmux save-buffer -',
      ['*'] = 'tmux save-buffer -',
    },
    cache_enabled = 1,
  }
end
