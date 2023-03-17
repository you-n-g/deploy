lua << EOF
require("plugins")
require("yx_conf")
EOF

" echo "Good"
" au BufReadPost *
"     \ if line("'\"") > 0 && line("'\"") <= line("$") && &filetype != "gitcommit" |
"         \ execute("normal `\"") |
"     \ endif
