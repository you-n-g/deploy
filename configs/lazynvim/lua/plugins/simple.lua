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
      {
        "<leader>Lr",
        function()
          require("luapad").toggle({
            context = {
              return_4 = function()
                return 4
              end,
            },
          })
        end,
        -- "<cmd>LuaRun<cr>",
        mode = "n",
        desc = "Toggle Current buffer to Luapad",
      },
    },
    -- TODO: attach to current buffer
  },
}
