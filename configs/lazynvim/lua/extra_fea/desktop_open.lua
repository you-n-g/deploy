
-- 比如 markdown 文件就 /mnt/c/Users/xiaoyang/OneDrive/APP/marktext-x64-win/MarkText.exe chat.md
-- TODO: 自动根据文件类型选择外部程序打开当前文件
local function open_file_with_app()
  local file = vim.fn.expand("%:p")
  if file == "" then
    print("No file associated with this buffer")
    return
  end

  -- 根据文件类型选择外部程序
  local ft = vim.bo.filetype
  local app = nil

  local app_map = {
    markdown = "/mnt/c/Users/xiaoyang/OneDrive/APP/marktext-x64-win/MarkText.exe",
    md = "/mnt/c/Users/xiaoyang/OneDrive/APP/marktext-x64-win/MarkText.exe",
  }

  app = app_map[ft]

  if not app then
    print("No associated external app for filetype: " .. ft)
    return
  end

    -- 用 jobstart 在后台启动；在 WSL 中必须通过 cmd.exe /C start 才能正确传递文件路径
    -- 但必须先把 WSL 路径转换成 Windows 路径，否则程序会打开但不会加载文件
    local win_file = vim.fn.system("wslpath -w " .. vim.fn.shellescape(file)):gsub("\n", "")
    local win_app = vim.fn.system("wslpath -w " .. vim.fn.shellescape(app)):gsub("\n", "")

    vim.fn.jobstart({
      "cmd.exe",
      "/C",
      "start",
      "",
      win_app,
      win_file,  -- 使用 Windows 路径，否则应用无法打开文件
    }, { detach = true })

    print("Opened with: " .. win_app .. "  File: " .. win_file)
end

vim.keymap.set("n", "<localleader>of", open_file_with_app, {
  noremap = true,
  desc = "Open current file with external app based on filetype",
})
