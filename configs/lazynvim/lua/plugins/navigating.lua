return {

  {
    "nvim-telescope/telescope.nvim",
    -- change some options
    opts = {
      defaults = {
        -- TODO: make it larger for content preview, less for file list
        layout_strategy = "vertical",
        layout_config = {
          -- prompt_position = "top",
          -- width = 0.95,
          -- height = 0.95,
          width = 0.99,
          height = 0.99,
        },
        -- sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  }
}
