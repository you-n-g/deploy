-- simple plugins are added here

return {
  {
    "rafcamlet/nvim-luapad",
    keys = {
      {
        "<leader>Li",
        function()
          require("luapad").init()
          -- It seems that this is not working
          -- require("luapad").attach({
          --   context = {
          --     return_4 = function()
          --       return 4
          --     end,
          --   },
          -- })
        end,
        -- "<cmd>Luapad<cr>",
        mode = "n",
        desc = "Luapad",
      },
    },
    -- TODO: attach to current buffer
  },
}
