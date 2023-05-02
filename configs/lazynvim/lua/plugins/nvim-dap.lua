-- get the python path from the venv(like which python)
-- get the conda env path
local function get_python_path()
  -- TODO: this is only compatible with linux
  -- Implement a version that works with windows as well
  local path = vim.fn.system("which python")
  -- right trim the '\n' in   path
  path = string.gsub(path, "\n$", "")
  if path == "" then
    return nil
  end
  return path
end

-- local py_path =
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
      keys = {
        {
          "<leader>dG",
          function()
            local config = {
              configurations = {
                {
                  name = "vscode json launcher",
                  type = "python",
                  request = "launch",
                  cwd = vim.fn.getcwd(),
                  python = get_python_path(),
                  stopOnEntry = true,
                  -- console = "externalTerminal",
                  debugOptions = {},
                  program = vim.fn.expand("%:p"),
                -- TODO: select args in neovim
                  args = {},
                },
              },
            }
            config["configurations"][1]["justMyCode#json"] = "${justMyCode:true}"
            -- dump `config` to a json file
            local json = vim.fn.json_encode(config)
            -- create .vscode dir if not exists
            vim.fn.mkdir(".vscode", "p")
            local ok, file = pcall(io.open, ".vscode/launch.json", "w")
            if ok then
              file:write(json)
              print("Generated .vscode/launch.json")
            else
              print("Error writing to file: " .. file)
            end
          end,
          mode = "n",
          desc = "Generate .vscode/launch.json",
        },
      },
      config = function()
        require("dap-python").setup(get_python_path())
        require("dap.ext.vscode").load_launchjs()
      end,
    },
  },
}
