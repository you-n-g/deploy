return {
  "saghen/blink.cmp",
  opts = {
    fuzzy = {
      sorts = {
        -- Always prioritize exact matches, case-sensitive.
        -- MOTIVATION: I hope I can exactly match the snippets with my musule.
        "exact",

        -- Sort by Fuzzy matching score.
        "score",

        -- Sort by `sortText` field from LSP server, defaults to `label`.
        -- `sortText` often differs from `label`.
        "sort_text",

        -- Sort by `label` field from LSP server, i.e. name in completion menu.
        -- Needed to sort results from LSP server by `label`,
        -- even though protocol specifies default value of `sortText` is `label`.
        "label",
      },
    },
  },
}

-- related links
-- - https://cmp.saghen.dev/configuration/fuzzy#sorting-priority-and-tie-breaking
-- - https://github.com/saghen/blink.cmp/issues/1642

-- You can insert function into one element of `sorts` array to sort the completion results.
-- function(a, b)
--   P(a)
--   return a.score > b.score
-- end,
