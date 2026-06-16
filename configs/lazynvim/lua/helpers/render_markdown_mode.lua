local M = {}

M.read_mode = true
M.wrap_by_win = {}

function M.opts(read_mode)
  if read_mode then
    return {
      anti_conceal = {
        enabled = false,
      },
      win_options = {
        concealcursor = {
          rendered = "nvic",
        },
      },
    }
  end

  return {
    anti_conceal = {
      enabled = true,
    },
    win_options = {
      concealcursor = {
        rendered = "",
      },
    },
  }
end

function M.apply_window_options(read_mode, win)
  win = win or vim.api.nvim_get_current_win()

  if read_mode then
    if M.wrap_by_win[win] == nil then
      M.wrap_by_win[win] = vim.wo[win].wrap
    end
    vim.wo[win].wrap = false
    return
  end

  if M.wrap_by_win[win] ~= nil then
    vim.wo[win].wrap = M.wrap_by_win[win]
    M.wrap_by_win[win] = nil
  else
    vim.wo[win].wrap = true
  end
end

function M.apply_buffer_window_options(read_mode, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    M.apply_window_options(read_mode, win)
  end
end

function M.apply_line_wrap_mode(read_mode, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "markdown" then
    return
  end

  local line_unwrap = require("extra_fea.line_unwrap")

  if read_mode then
    line_unwrap.disable_buffer(bufnr)
  else
    line_unwrap.enable_buffer(bufnr)
  end
end

function M.set(read_mode)
  M.read_mode = read_mode
  vim.g.render_markdown_read_mode = read_mode

  local render = require("render-markdown")
  render.setup(M.opts(read_mode))
  render.enable()

  if vim.bo.filetype == "markdown" then
    local bufnr = vim.api.nvim_get_current_buf()
    if read_mode then
      M.apply_line_wrap_mode(read_mode, bufnr)
      M.apply_buffer_window_options(read_mode, bufnr)
    else
      M.apply_buffer_window_options(read_mode, bufnr)
      M.apply_line_wrap_mode(read_mode, bufnr)
    end
    render.render({
      buf = bufnr,
      event = "ReadModeToggle",
    })
  end

  vim.notify("RenderMarkdown read mode: " .. (read_mode and "on" or "off"))
end

function M.toggle()
  M.set(not M.read_mode)
end

function M.configure_markdown_buffer(buf)
  if vim.bo[buf].filetype ~= "markdown" then
    return
  end
  M.apply_line_wrap_mode(M.read_mode, buf)
  M.apply_buffer_window_options(M.read_mode, buf)
  vim.keymap.set("n", "<leader>um", "<cmd>RenderMarkdownReadModeToggle<cr>", {
    buffer = buf,
    desc = "Toggle Markdown read mode",
  })
end

function M.enforce_current_markdown_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "markdown" then
    return
  end
  M.apply_line_wrap_mode(M.read_mode, bufnr)
  M.apply_window_options(M.read_mode)
end

function M.setup()
  if M.did_setup then
    return
  end
  M.did_setup = true

  vim.api.nvim_create_user_command("RenderMarkdownReadMode", function(opts)
    local arg = opts.args
    if arg == "on" then
      M.set(true)
    elseif arg == "off" then
      M.set(false)
    elseif arg == "" or arg == "toggle" then
      M.toggle()
    else
      error("usage: RenderMarkdownReadMode [on|off|toggle]")
    end
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
    desc = "Toggle render-markdown read-priority mode",
  })

  vim.api.nvim_create_user_command("RenderMarkdownReadModeToggle", function()
    M.toggle()
  end, {
    desc = "Toggle render-markdown read-priority mode",
  })

  local group = vim.api.nvim_create_augroup("RenderMarkdownReadMode", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(args)
      M.configure_markdown_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function(args)
      M.configure_markdown_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = group,
    callback = function()
      if M.read_mode then
        M.enforce_current_markdown_buffer()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      if vim.bo.filetype == "markdown" then
        M.configure_markdown_buffer(vim.api.nvim_get_current_buf())
      end
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "wrap",
    callback = function()
      vim.schedule(function()
        if M.read_mode and vim.bo.filetype == "markdown" then
          M.apply_window_options(true)
        end
      end)
    end,
  })

  if vim.bo.filetype == "markdown" then
    M.configure_markdown_buffer(vim.api.nvim_get_current_buf())
  end

  vim.schedule(function()
    if vim.bo.filetype == "markdown" then
      M.configure_markdown_buffer(vim.api.nvim_get_current_buf())
    end
  end)
end

return M
