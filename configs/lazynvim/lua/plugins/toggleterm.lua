local opts = {
  -- size can be a number or function which is passed the current terminal
  size = function(term)
    if term.direction == "horizontal" then
      return 15
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  open_mapping = [[<c-\><c-\>]],
  -- on_open = fun(t: Terminal), -- function to run when the terminal opens
  hide_numbers = true, -- hide the number column in toggleterm buffers
  shade_filetypes = {},
  shade_terminals = true,
  -- shading_factor = '<number>', -- the degree by which to darken to terminal colour, default: 1 for dark backgrounds, 3 for light
  -- start_in_insert = true,
  start_in_insert = false,
  insert_mappings = true, -- whether or not the open mapping applies in insert mode
  persist_size = true,
  -- direction = 'vertical' | 'horizontal' | 'window' | 'float',
  -- direction = 'float',
  direction = "horizontal",
  close_on_exit = true, -- close the terminal window when the process exits
  shell = vim.o.shell, -- change the default shell
  -- This field is only relevant if direction is set to 'float'
  float_opts = {
    -- The border key is *almost* the same as 'nvim_open_win'
    -- see :h nvim_open_win for details on borders however
    -- the 'curved' border is a custom border type
    -- not natively supported but implemented in this plugin.
    -- border = 'single' | 'double' | 'shadow' | 'curved' | ... other options supported by win open
    -- width = <value>,
    -- height = <value>,
    -- winblend = 3,
    highlights = {
      border = "Normal",
      background = "Normal",
    },
  },
}

return {
  {
    "akinsho/toggleterm.nvim",
    config = function()
      require("toggleterm").setup(opts)
      -- config will override automatically setup(opts).
      for _, mode in pairs({ "i", "v", "n", "t" }) do
        for i = 1, 5 do
          -- vim.api.nvim_set_keymap(mode, "<c-"..tostring(i)..">", "<cmd>ToggleTerm "..tostring(i).."<cr>", {expr = true, noremap = true})
          for _, lhs in ipairs({"<F" .. tostring(i) .. ">", "<localleader>" .. tostring(i)}) do
            vim.api.nvim_set_keymap(
              mode,
              lhs,
              "<cmd>ToggleTerm " .. tostring(i) .. "<cr>",
              { expr = false, noremap = true }
            )
            -- expr = false 非常重要； 不然就会触发 vim mapping 的  <expr> 机制， 导致先用vim命令执行一遍， 再把结果作为map的目标
          end
        end
      end
      vim.api.nvim_set_keymap("t", "<c-w>w", "<c-\\><c-n><c-w><c-w>", { expr = false, noremap = true })
    end,
  },
}
