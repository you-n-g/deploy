-- global functions

--- It will stop at the first nil
---@vararg: all kinds of variable yo want to inspect
function P(...)
  local args = { ... }
  for i, v in ipairs(args) do
    print("Arg:", i)
    print(vim.inspect(v))
  end
end

-- TODO: get comprehensive information of current status.

-- module features
local M = {}

---
--- Get the visual selection in vim.
-- This function returns a table with the start and end positions of the visual selection.
--
-- We don't use  vim.fn.getpos("'<") because:
-- - https://www.reddit.com/r/neovim/comments/13mfta8/reliably_get_the_visual_selection_range/
-- - We must escape visual mode before make  "<" ">"  take effects
--
-- @return table containing the start and end positions of the visual selection
-- For example, it might return: { start = { row = 1, col = 5 }, ["end"] = { row = 3, col = 20 } }
function M.get_visual_selection()
  local pos = vim.fn.getpos("v")
  local begin_pos = { row = pos[2], col = pos[3] }
  pos = vim.fn.getpos(".")
  local end_pos = { row = pos[2], col = pos[3] }
  if (begin_pos.row < end_pos.row) or ((begin_pos.row == end_pos.row) and (begin_pos.col <= end_pos.col)) then
    return { start = begin_pos, ["end"] = end_pos }
  else
    return { start = end_pos, ["end"] = begin_pos }
  end
end

function M.get_visual_selection_content()
  local mode = vim.api.nvim_get_mode().mode
  local range_pos = M.get_visual_selection()
  local lines = vim.api.nvim_buf_get_lines(0, range_pos["start"]["row"] - 1, range_pos["end"]["row"], false)
  if #lines > 0 and mode == "v" then
    lines[1] = string.sub(lines[1], range_pos["start"]["col"])
    if #lines > 1 then
      lines[#lines] = string.sub(lines[#lines], 1, range_pos["end"]["col"])
    else
      lines[1] = string.sub(lines[1], 1, range_pos["end"]["col"] + 1 - range_pos["start"]["col"])
    end
  end
  -- lines[#lines] = "return " .. lines[#lines]
  return table.concat(lines, "\n")
end

function M.get_cred()
  local fname = "gpt.gpg"
  -- local is_local_open = vim.fn.system("nc -z 127.0.0.1 4000") == 0
  local is_local_open = false

  local vim_cred = vim.fn.system("tmux show-env -g vim_cred | cut -d= -f2"):gsub("%s+", "")
  if vim_cred == "local" then
    -- by default local is disabled
    is_local_open = vim.fn.system("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4000") == "200"
  end

  if is_local_open then
    return {
      type = "openai",
      api_base = "http://127.0.0.1:4000",
      model = "gpt-4",
      api_key = "sk-1234",
    }
  else
    return {
      type = "azure",
      api_base = string.gsub(vim.fn.system(
        "gpg -q --decrypt " .. vim.fn.expand("$HOME") .. "/deploy/keys/" .. fname .. " | sed -n 1p"
      ), "\n$", ""),
      model = string.gsub(vim.fn.system(
        "gpg -q --decrypt " .. vim.fn.expand("$HOME") .. "/deploy/keys/" .. fname .. " | sed -n 2p"
      ), "\n$", ""),
      api_key = string.gsub(vim.fn.system(
        "gpg -q --decrypt " .. vim.fn.expand("$HOME") .. "/deploy/keys/" .. fname .. " | sed -n 3p"
      ), "\n$", ""),
    }
  end
end

function M.export_cred_env()
  -- This is hard coded with ChatGPT.nvim
  -- this is designed for chatgpt.nvim
  local cred = require("extra_fea.utils").get_cred()
  vim.env.OPENAI_API_TYPE = 'azure'
  vim.env.OPENAI_API_BASE = cred.api_base
  vim.env.OPENAI_API_AZURE_ENGINE = cred.model
  vim.env.OPENAI_API_KEY = cred.api_key
end

return M
