if vim.fn.system('tmux -V') ~= '' then
  -- I prefer the tmux clipboard as "+*" (based on my experience, it is more safety than systemclipboard);
  -- vim.g.clipboard = {
  --   name = 'tmux',
  --   copy = {
  --     ['+'] = 'tmux load-buffer -w -',
  --     ['*'] = 'tmux load-buffer -w -',
  --   },
  --   paste = {
  --     ['+'] = 'tmux save-buffer -',
  --     ['*'] = 'tmux save-buffer -',
  --   },
  --   cache_enabled = 1,
  -- }
end
