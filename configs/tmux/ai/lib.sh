#!/bin/bash
# Shared helpers for AI window detection

AI_PROC_PAT='(^|/)(claude|gemini|codex)$'

# Find the first AI process in the subtree rooted at a pane PID.
# Prints "PID COMM" (e.g. "12345 claude") and returns 0, or returns 1 if none.
# For loops, pre-set _ps_cache to avoid repeated ps calls:
#   _ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)
_find_ai_pid() {
    local ps_data="${_ps_cache:-$(ps -ax -o pid,ppid,comm 2>/dev/null)}"
    echo "$ps_data" | awk -v root="$1" -v pat="$AI_PROC_PAT" '
        { children[$2] = children[$2] " " $1; name[$1] = $3 }
        END {
            n = split(children[root], q, " ")
            while (n > 0) {
                new_n = 0
                for (i = 1; i <= n; i++) {
                    p = q[i]; if (p == "") continue
                    if (name[p] ~ pat) { print p " " name[p]; exit 0 }
                    m = split(children[p], t, " ")
                    for (j = 1; j <= m; j++) if (t[j] != "") nq[++new_n] = t[j]
                }
                n = new_n; for (k=1;k<=n;k++) q[k]=nq[k]; delete nq
            }
            exit 1
        }'
}

# Check if a pane has an AI process (boolean wrapper around _find_ai_pid).
_has_ai_proc() {
    _find_ai_pid "$1" > /dev/null
}
