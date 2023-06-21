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

local function auto_install_debugpy()
  local res = vim.fn.system("python -m debugpy --version")
  -- if "No module name" not in res
  if string.find(res, "No module name") then
    print("Auto installing debugpy")
    vim.fn.system("python -m pip install debugpy")
  end
end

local function get_venv_python_path()
  local path = vim.fn.expand("$CONDA_PREFIX")
  local basename = vim.fn.fnamemodify(path, ":t")
  return "~/.virtualenvs/debugpy-" .. basename .. "/bin/python"
end

local function auto_virtual_env()
  -- the advantage of this is that it will not add extra packages into the conda env
  local path = vim.fn.expand("$CONDA_PREFIX")
  -- get base name of path
  local basename = vim.fn.fnamemodify(path, ":t")
  if vim.fn.filereadable("~/.virtualenvs/debugpy-" .. basename .. "/bin/python") ~= 1 then
    vim.fn.system("mkdir -p ~/.virtualenvs")
    vim.fn.system("cd ~/.virtualenvs && python -m venv --system-site-packages debugpy-" ..
      basename .. " && debugpy-" .. basename .. "/bin/python -m pip install debugpy")
  end
end

-- local py_path =
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- NOTE:
      -- Bad cases:
      --   - Python Debuger is much slower than normal running
      --     - It may be caused by joblib
      --   - So insert ipdb breakpoints is a better choice when performance affect much
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
                  -- '${workspaceFolder}' looks good too.
                  python = get_python_path(),
                  stopOnEntry = true,
                  -- console = "externalTerminal",
                  debugOptions = {},
                  program = vim.fn.expand("%:p"),
                  -- TODO: select args in neovim
                  args = {},
                  console = "integratedTerminal", -- This is very important. Otherwise, the stdin will mixed with std in...And the program will get stuck at the stdin.
                                                  -- https://github.com/mfussenegger/nvim-dap/discussions/430
                  justMyCode = true,
                },
              },
            }
            -- NOTE: this does not work...
            -- - config["configurations"][1]["justMyCode#json"] = "${justMyCode:true}"
            -- - For stopping on uncaught exception: please refer to `require'dap'.set_exception_breakpoints()`

            -- dump `config` to a json file
            local json = vim.fn.json_encode(config)
            vim.fn.mkdir(".vscode", "p") -- create .vscode dir if not exists

            local ok, file = pcall(io.open, ".vscode/launch.json", "w")
            if ok and file ~= nil then
              file:write(json)
              file:close()
              print("Generated .vscode/launch.json")
              vim.cmd("edit .vscode/launch.json")
            else
              print("Error writing to file: " .. file)
            end
          end,
          mode = "n",
          desc = "Generate .vscode/launch.json",
        },
      },
      config = function()
        -- auto_install_debugpy()
        -- require("dap-python").setup(get_python_path())
        auto_virtual_env()
        require("dap-python").setup(get_venv_python_path())

        -- Following the guideline in homepage does not necessarily work
        -- require('dap-python').setup('~/.virtualenvs/debugpy/bin/python')

        require("dap.ext.vscode").load_launchjs()
      end,
    },
    -- NOTE: cheatsheet
    -- - good shortcuts: o(open file for breakpoints/frame...)
  },
}
