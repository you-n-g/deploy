local function get_snippet_file()
  local ft = vim.bo.filetype
  return vim.fn.expand("~/.config/nvim/luasnip_snippets/" .. ft .. ".snippets")
end

return {
  {
    -- "L3MON4D3/LuaSnip",
    "L3MON4D3/LuaSnip",
    -- follow latest release.
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
    -- TODO: add as
    config = function(_, opts)
      opts["enable_autosnippets"] = true
      -- This is necessary. Otherwise snippets like pypdb with  `"autotrigger": true` will not work
      require("luasnip").setup(opts) -- default behaviour: https://github.com/folke/lazy.nvim#-plugin-spec
      require("luasnip.loaders.from_vscode").lazy_load({ paths = { "./luasnip_snippets" } })
      require("luasnip.loaders.from_lua").load({ paths = "./luasnip_snippets" })
      require("luasnip.loaders.from_snipmate").load({ paths = "./luasnip_snippets" })
    end,
    -- NOTE: cheatsheets
    -- - Config documents: https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
    keys = {
      {
        "<leader>sN",
        -- `only_sort_text=true` will only search text without filename
        -- https://github.com/nvim-telescope/telescope.nvim/issues/564
        -- [[:Telescope grep_string only_sort_text=true<cr>]],
        function()
          local search_path = vim.fn.expand("~/.config/nvim/luasnip_snippets")  -- TODO: get the absolute path of the path.
          require'telescope.builtin'.live_grep{ cwd = search_path, search = '' }
          -- The file name are very clear to user. So we don't include it in the search.
          -- require'telescope.builtin'.grep_string{cwd=search_path, shorten_path = true, word_match = "-w", only_sort_text = false, search = '' }
        end,
        mode = "n",
        desc = "Search by snippets content",
      },
      -- sNf to use telescope to select the right snippet file
      {
        "<leader>fN",
        function()
          local search_path = vim.fn.expand("~/.config/nvim/luasnip_snippets")
          require'telescope.builtin'.find_files{ cwd = search_path }
        end,
        mode = "n",
        desc = "Select snippet file",
      },
      {
        "<leader>cs",
        function()
          local text = require("extra_fea.utils").get_visual_selection_content()
          local lines = vim.split(text, "\n")
          if #lines == 0 or (#lines == 1 and lines[1] == "") then return end

          local min_indent = nil
          for _, line in ipairs(lines) do
            if line:match("%S") then
              local indent = line:match("^%s*"):len()
              min_indent = min_indent and math.min(min_indent, indent) or indent
            end
          end
          min_indent = min_indent or 0

          local snippet_file = get_snippet_file()

          local file = io.open(snippet_file, "a")
          if file then
            file:write("\nsnippet <trigger> \"<Description>\"\n")
            for _, line in ipairs(lines) do
              file:write("\t" .. line:sub(min_indent + 1) .. "\n")
            end
            file:close()
            vim.cmd("vsplit " .. snippet_file)
            vim.cmd("$")
            require("luasnip.loaders.from_snipmate").load({ paths = "./luasnip_snippets" })
          else
             vim.notify("Could not open " .. snippet_file, vim.log.levels.ERROR)
          end
        end,
        mode = "v",
        desc = "Append selection to SnipMate file",
      },
      {
        "<leader>cS",
        function()
          local snippet_file = get_snippet_file()
          vim.cmd("vsplit " .. snippet_file)
        end,
        mode = "n",
        desc = "Open SnipMate snippet file",
      },
      {
        "<C-c>", -- choices
        function()
          local ls = require("luasnip")
          if ls.choice_active() then
            ls.change_choice(1)
          end
        end,
        mode = { "i", "s" },
        silent = true,
        desc = "LuaSnip: change choice",
      },
    },
  },
}
