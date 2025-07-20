local ls = require("luasnip")
local s = ls.snippet
-- local sn = ls.snippet_node
-- local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require("luasnip.util.events")
local ai = require("luasnip.nodes.absolute_indexer")
local fmt = require("luasnip.extras.fmt").fmt
local extras = require("luasnip.extras")
local m = extras.m
local l = extras.l
local rep = extras.rep
local postfix = require("luasnip.extras.postfix").postfix

-- return {
--     s("ctrig", t("also loaded!!")),
--     s("trig", c(1, {
--         t("Ugh boring, a text node"),
--         i(nil, "At least I can edit something now..."),
--         f(function(args) return "Still only counts as text!!" end, {})
--      }))
-- }

-- Not necessary, due to sh.snippets has already support it and is easier to use.
-- snippet: EOF (usually for comments)
-- return {
--   s(
--     "EOFMY",
--     fmt(
--       [[
-- false << "{}" > /dev/null
-- {}
-- {}
-- ]],
--       {
--         c(1, { t("EOF"), t("PY"), t("MARKDOWN") }), -- selectable marker
--         i(2, "Comments or content"), -- main comment/content area
--         rep(1), -- repeats chosen marker
--       }
--     )
--   ),
-- }
