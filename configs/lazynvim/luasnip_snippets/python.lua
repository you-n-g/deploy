local ls = require("luasnip")
local s = ls.snippet
-- local sn = ls.snippet_node
-- local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
-- local d = ls.dynamic_node
-- local r = ls.restore_node
-- local events = require("luasnip.util.events")
-- local ai = require("luasnip.nodes.absolute_indexer")
-- local fmt = require("luasnip.extras.fmt").fmt
-- local extras = require("luasnip.extras")
-- local m = extras.m
-- local l = extras.l
-- local rep = extras.rep
-- local postfix = require("luasnip.extras.postfix").postfix

return {
    s("pwd", f(function(args) return "python " .. vim.fn.expand("%") .. " " .. require("extra_fea/repl_workflow").get_current_function_name() end, {})),
    s("dirn", {
        t("from pathlib import Path"),
        t({"", [[DIRNAME = Path(__file__).absolute().resolve().parent  if globals().get("__file__") is not None else Path(".")]], ""}),
        f(function(args) return '# DIRNAME = Path("' .. vim.fn.expand("%") .. '").absolute().resolve().parent' end, {})
    }),
    -- 不能在函数里面直接插入 \n 换行符，而是需要在  t 中插入 "" 字符串才能换行
    -- s("dirn", f(function(args) return 'from pathlib import Path\nDIRNAME = Path(__file__).absolute().resolve().parent\n# DIRNAME = Path("' .. vim.fn.expand("%") .. '").absolute().resolve().parent' end, {})),
}
