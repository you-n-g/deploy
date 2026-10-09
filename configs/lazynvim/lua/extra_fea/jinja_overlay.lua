--[[
Jinja highlighting on top of Markdown, detected from the content.

AI4AI templates such as watch.md keep their .md suffix, so the suffix cannot
say whether a file holds Jinja. A markdown buffer is scanned instead; when it
has {% %} / {{ }} / {# #} tags they are coloured with extmarks at a priority
above treesitter's. The filetype stays "markdown", so treesitter's markdown
highlighting, render-markdown and the markdown ftplugins work as before.

The colouring is token-level, not a Jinja parse: delimiters, the statement
keyword and Jinja's word operators, filters (a name after "|"), names,
strings, numbers, and comments.

Disable for one buffer with `:let b:jinja_overlay = v:false`.
--]]
local M = {}

local ns = vim.api.nvim_create_namespace("JinjaOverlay")
local PRIORITY = 200 -- treesitter highlights at 100
local DEBOUNCE_MS = 150

local CLOSE = { ["{%"] = "%}", ["{{"] = "}}", ["{#"] = "#}" }

-- Words that are keywords anywhere in a tag; the first word of a {% %} tag is
-- one as well, which covers block/endblock/extends/... without listing them.
local KEYWORDS = {}
for _, word in ipairs({
  "in", "not", "and", "or", "is", "if", "else", "recursive", "with", "without",
  "context", "ignore", "missing", "as", "import", "from", "true", "false", "none",
  "True", "False", "None",
}) do
  KEYWORDS[word] = true
end

local function set_highlights()
  local links = {
    JinjaDelimiter = "PreProc",
    JinjaKeyword = "Keyword",
    JinjaFilter = "Function",
    JinjaName = "Identifier",
    JinjaString = "String",
    JinjaNumber = "Number",
    JinjaComment = "Comment",
  }
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

-- Tags as {open = "{%", s = first byte, e = last byte}, 1-based into text. A
-- tag must close before the next opener: Jinja tags do not nest, and this
-- keeps a stray "{#" (pandoc's `# Title {#id}`) from swallowing the document
-- up to some later "#}".
local function find_tags(text)
  local tags = {}
  local pos = 1
  while true do
    local s = text:find("{[%%{#]", pos)
    if not s then
      break
    end
    local open = text:sub(s, s + 1)
    local close = text:find(CLOSE[open], s + 2, true)
    local next_open = text:find("{[%%{#]", s + 2)
    if not close or (next_open and next_open < close) then
      pos = s + 1
    else
      tags[#tags + 1] = { open = open, s = s, e = close + 1 }
      pos = close + 2
    end
  end
  return tags
end

-- Tokens inside a {% %} / {{ }} body: {group, s, e} with 1-based inclusive bytes.
local function tokenize(text, s, e, is_statement)
  local tokens = {}
  local i = s
  local first_word = is_statement
  local after_pipe = false
  while i <= e do
    local c = text:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c == "'" or c == '"' then
      local close = text:find(c, i + 1, true)
      local stop = (close and close <= e) and close or e
      tokens[#tokens + 1] = { "JinjaString", i, stop }
      i = stop + 1
      first_word, after_pipe = false, false
    elseif c:match("%d") then
      local _, stop = text:find("^[%d%.]+", i)
      stop = math.min(stop, e)
      tokens[#tokens + 1] = { "JinjaNumber", i, stop }
      i = stop + 1
      first_word, after_pipe = false, false
    elseif c:match("[%a_]") then
      local _, stop = text:find("^[%w_]+", i)
      stop = math.min(stop, e)
      local word = text:sub(i, stop)
      local group = "JinjaName"
      if first_word or KEYWORDS[word] then
        group = "JinjaKeyword"
      elseif after_pipe then
        group = "JinjaFilter"
      end
      tokens[#tokens + 1] = { group, i, stop }
      i = stop + 1
      first_word, after_pipe = false, false
    else
      after_pipe = c == "|"
      i = i + 1
    end
  end
  return tokens
end

-- 1-based byte offset in the joined buffer text -> 0-based (row, col).
local function make_locator(lines)
  local starts = {}
  local offset = 1
  for row, line in ipairs(lines) do
    starts[row] = offset
    offset = offset + #line + 1
  end
  return function(byte)
    local lo, hi = 1, #starts
    while lo < hi do
      local mid = math.floor((lo + hi + 1) / 2)
      if starts[mid] <= byte then
        lo = mid
      else
        hi = mid - 1
      end
    end
    return lo - 1, byte - starts[lo]
  end
end

local function render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if vim.bo[buf].filetype ~= "markdown" or vim.b[buf].jinja_overlay == false then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  local tags = find_tags(text)
  vim.b[buf].jinja_detected = #tags > 0
  if #tags == 0 then
    return
  end

  local locate = make_locator(lines)
  local function mark(group, s, e)
    local row, col = locate(s)
    local end_row, end_col = locate(e)
    vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
      end_row = end_row,
      end_col = end_col + 1,
      hl_group = group,
      priority = PRIORITY,
    })
  end

  for _, tag in ipairs(tags) do
    if tag.open == "{#" then
      mark("JinjaComment", tag.s, tag.e)
    else
      -- Delimiters include whitespace control: {%- -%} {{+ +}}.
      local open_end = tag.s + 1
      if text:sub(open_end + 1, open_end + 1):match("[-+]") then
        open_end = open_end + 1
      end
      local close_start = tag.e - 1
      if close_start - 1 > open_end and text:sub(close_start - 1, close_start - 1):match("[-+]") then
        close_start = close_start - 1
      end
      mark("JinjaDelimiter", tag.s, open_end)
      mark("JinjaDelimiter", close_start, tag.e)
      for _, token in ipairs(tokenize(text, open_end + 1, close_start - 1, tag.open == "{%")) do
        mark(token[1], token[2], token[3])
      end
    end
  end
end

local timers = {}

local function schedule_render(buf)
  local timer = timers[buf]
  if not timer then
    timer = vim.uv.new_timer()
    timers[buf] = timer
  end
  timer:stop()
  timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    render(buf)
  end))
end

set_highlights()

local group = vim.api.nvim_create_augroup("JinjaOverlay", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = group,
  callback = function(args)
    render(args.buf)
  end,
})
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(args)
    if vim.bo[args.buf].filetype == "markdown" then
      schedule_render(args.buf)
    end
  end,
})
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(args)
    local timer = timers[args.buf]
    if timer then
      timer:stop()
      timer:close()
      timers[args.buf] = nil
    end
  end,
})

M.render = render
M.find_tags = find_tags
return M
