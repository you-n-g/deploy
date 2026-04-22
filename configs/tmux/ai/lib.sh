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

_tmux_current_target() {
    if [[ -n "$TMUX" ]]; then
        tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null
    fi
}

_format_relative_age() {
    local diff="$1"

    if   (( diff < 60 ));    then printf '%ss' "$diff"
    elif (( diff < 3600 ));  then printf '%sm' "$((diff / 60))"
    elif (( diff < 86400 )); then printf '%sh' "$((diff / 3600))"
    else                          printf '%sd' "$((diff / 86400))"
    fi
}

# Print unique AI windows as tab-separated rows:
#   last_visit  session:index  window_name  window_id  pane_pid  window_activity
_ai_window_rows() {
    _ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)
    tmux list-panes "$@" \
        -F $'#{?@last_visit,#{@last_visit},#{window_activity}}\t#{session_name}:#{window_index}\t#{window_name}\t#{window_id}\t#{pane_pid}\t#{window_activity}' 2>/dev/null |
    while IFS=$'\t' read -r wvisit sess_win wname wid pane_pid wact_raw; do
        if _has_ai_proc "$pane_pid"; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$wvisit" "$sess_win" "$wname" "$wid" "$pane_pid" "$wact_raw"
        fi
    done |
    sort -t $'\t' -k1,1nr -k6,6nr |
    awk -F '\t' '!seen[$4]++'
}

# Count AI windows that are actively producing output right now.
# Matches the yellow ○ "running" case in _ai_window_fzf_list: window_activity
# within the last 1 second.
_ai_running_count() {
    local now
    now=$(date +%s)
    _ai_window_rows -a | awk -F '\t' -v now="$now" '(now - $6) <= 1 { c++ } END { print c+0 }'
}

# Read _ai_window_rows from stdin and print fzf-ready lines:
#   window_id session:index <ansi-decorated label>
_ai_window_fzf_list() {
    local current_target="${1:-}"
    local now="${2:-$(date +%s)}"

    while IFS=$'\t' read -r wvisit sess_win wname wid pane_pid wact_raw; do
        local sort_key status rel_visit rel_act time_info

        if [[ "$sess_win" == "$current_target" ]]; then
            sort_key=0
            status=$'\033[36m◆\033[0m '
        elif (( now - wact_raw > 1 )); then
            sort_key=1
            status=$'\033[32m●\033[0m '
        else
            sort_key=05
            status=$'\033[33m○\033[0m '
        fi

        rel_visit=$(_format_relative_age $((now - wvisit)))
        rel_act=$(_format_relative_age $((now - wact_raw)))

        if (( wvisit == wact_raw )); then
            time_info="[act ${rel_act}]"
        else
            time_info="[visit ${rel_visit} | act ${rel_act}]"
        fi

        printf '%s\t%s\t%s %s %b%s  \033[2m%s\033[0m\n' \
            "$sort_key" "$wvisit" "$wid" "$sess_win" "$status" "$wname" "$time_info"
    done |
    sort -t $'\t' -k1,1 -k2,2nr |
    cut -f3-
}
