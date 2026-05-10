#!/bin/bash
# Shared helpers for AI window detection

AI_PROC_PAT='(^|/)(claude|gemini|codex)$'
_AI_FZF_PREVIEW_HEIGHT=85%  # fzf preview-window height for AI-window selectors
_AI_FZF_SESSION_COLOR_CODES=(31 32 33 34 35 36 91 92 93 94 95 96)
_ai_fzf_session_color_names=()
_ai_fzf_session_color_values=()
_ai_fzf_used_session_color_codes=()

# Find the first AI process in the subtree rooted at a pane PID.
# Prints "PID COMM" (e.g. "12345 claude") and returns 0, or returns 1 if none.
# For loops, pass one ps snapshot to avoid repeated ps calls:
#   ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)
#   _has_ai_proc "$pane_pid" "$ps_cache"
_find_ai_pid() {
    local ps_data="${2:-$(ps -ax -o pid,ppid,comm 2>/dev/null)}"
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
    _find_ai_pid "$1" "${2:-}" > /dev/null
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

_ai_fzf_reset_session_colors() {
    _ai_fzf_session_color_names=()
    _ai_fzf_session_color_values=()
    _ai_fzf_used_session_color_codes=()
}

_ai_fzf_get_session_color() {
    local session_name="$1"
    local out_var="$2"
    local i

    for ((i = 0; i < ${#_ai_fzf_session_color_names[@]}; i++)); do
        if [[ "${_ai_fzf_session_color_names[$i]}" == "$session_name" ]]; then
            printf -v "$out_var" '%s' "${_ai_fzf_session_color_values[$i]}"
            return 0
        fi
    done

    printf -v "$out_var" '%s' ""
    return 1
}

_ai_fzf_set_session_color() {
    local session_name="$1"
    local color="$2"

    _ai_fzf_session_color_names+=("$session_name")
    _ai_fzf_session_color_values+=("$color")
    _ai_fzf_used_session_color_codes+=("$color")
}

_ai_fzf_color_is_used() {
    local color="$1"
    local used

    for used in "${_ai_fzf_used_session_color_codes[@]}"; do
        [[ "$used" == "$color" ]] && return 0
    done

    return 1
}

_ai_fzf_session_color_code() {
    local session_name="$1"
    local out_var="$2"
    local color
    local checksum start offset candidate color_count

    _ai_fzf_get_session_color "$session_name" color
    [[ -n "$color" ]] && { printf -v "$out_var" '%s' "$color"; return; }

    color_count="${#_AI_FZF_SESSION_COLOR_CODES[@]}"
    checksum=$(printf '%s' "$session_name" | cksum)
    checksum="${checksum%% *}"
    start=$((checksum % color_count))

    for ((offset = 0; offset < color_count; offset++)); do
        candidate="${_AI_FZF_SESSION_COLOR_CODES[$(((start + offset) % color_count))]}"
        if ! _ai_fzf_color_is_used "$candidate"; then
            color="$candidate"
            break
        fi
    done

    [[ -z "$color" ]] && color="${_AI_FZF_SESSION_COLOR_CODES[$start]}"
    _ai_fzf_set_session_color "$session_name" "$color"
    printf -v "$out_var" '%s' "$color"
}

_ai_fzf_colored_session_target() {
    local sess_win="$1"
    local out_var="$2"
    local session_name="${sess_win%:*}"
    local window_index="${sess_win##*:}"
    local session_color

    _ai_fzf_session_color_code "$session_name" session_color
    printf -v "$out_var" '\033[%sm%s\033[0m:%s' "$session_color" "$session_name" "$window_index"
}

_ai_pane_pid_set() {
    local pane_pids="$1"
    local ps_data="$2"

    awk -v pat="$AI_PROC_PAT" '
    FNR == NR {
        if ($1 ~ /^[0-9]+$/) pane_pid[$1] = 1
        next
    }
    {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        split(line, proc, /[[:space:]]+/)
        if (proc[1] !~ /^[0-9]+$/) next
        parent[proc[1]] = proc[2]
        name[proc[1]] = proc[3]
    }
    END {
        for (pid in name) {
            if (name[pid] !~ pat) continue
            current = pid
            while (current in parent) {
                if (current in pane_pid) {
                    found[current] = 1
                    break
                }
                current = parent[current]
            }
        }
        for (pid in found) print pid
    }
    ' <(printf '%s\n' "$pane_pids") <(printf '%s\n' "$ps_data")
}

# Print unique AI windows as tab-separated rows, sorted by last_visit desc.
#
# Usage: _ai_window_rows [-a] [-s -t SESSION] [tmux list-panes options]
#   -a              scan all sessions
#   -s -t SESSION   scan a specific session only
#
# Output columns (TAB-separated):
#   $1 last_visit      epoch of last user visit (falls back to window_activity)
#   $2 session:index   e.g. "work:3"
#   $3 window_name     e.g. "claude"
#   $4 window_id       e.g. "@7"
#   $5 pane_pid        root PID of the pane
#   $6 activity_epoch  tmux window activity
#   $7 unread_flag     1 if the agent finished while not visible
#   $8 running_flag    1 if the agent hook says this window is running
#   $9 attribute       short description generated once after first stop
#
# Example output:
#   1745000100  work:3   claude   @7   12345   1745000099   1   0   edits tmux hooks
#   1744999800  work:1   gemini   @2   67890   1744999800   0   1   reviews config
_ai_window_rows() {
    local pane_rows pane_pids ps_cache ai_pane_pids pane_pid

    pane_rows=$(tmux list-panes "$@" \
        -F $'#{?@last_visit,#{@last_visit},#{window_activity}}\t#{session_name}:#{window_index}\t#{window_name}\t#{window_id}\t#{pane_pid}\t#{window_activity}\t#{@ai_agent_running}\t#{@ai_agent_unread}\t#{@ai_agent_attribute}' 2>/dev/null) || return 1
    pane_pids=$(printf '%s\n' "$pane_rows" | awk -F '\t' '{ print $5 }')
    ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null) || return 1
    ai_pane_pids=$(_ai_pane_pid_set "$pane_pids" "$ps_cache")

    declare -A has_ai_proc_by_pane=()
    while IFS= read -r pane_pid; do
        [[ -n "$pane_pid" ]] && has_ai_proc_by_pane["$pane_pid"]=1
    done <<< "$ai_pane_pids"

    while IFS=$'\t' read -r last_visit sess_win wname wid pane_pid window_activity hook_running hook_unread attribute; do
        if [[ "${has_ai_proc_by_pane[$pane_pid]:-}" == 1 ]]; then
            attribute=${attribute//$'\t'/ }
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$last_visit" "$sess_win" "$wname" "$wid" "$pane_pid" \
                "$window_activity" "$hook_unread" "$hook_running" "$attribute"
        fi
    done <<< "$pane_rows" |
    sort -t $'\t' -k1,1nr -k6,6nr |
    awk -F '\t' '!seen[$4]++' |
    awk -F '\t' '
    {
        print $1+0 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6+0 "\t" $7+0 "\t" $8+0 "\t" $9
    }
    '
}

# Count AI windows that are actively producing output right now.
_ai_running_count() {
    _ai_window_rows -a | awk -F '\t' '$8 == 1 { c++ } END { print c+0 }'
}

# Format _ai_window_rows output (read from stdin) into fzf-ready lines.
#
# Usage: _ai_window_rows [-a] | _ai_window_fzf_list [current_target [now]]
#   current_target   session:index of the currently active window, e.g. "work:3"
#   now              epoch seconds (defaults to $(date +%s))
#
# Output columns (SPACE-separated, ready for fzf --ansi):
#   $1 window_id      e.g. "@7"
#   $2 session:index  e.g. "work:3" (session name is ANSI-colored)
#   $3+  ANSI label   status-symbol + window_name + unread mark + time info
#
# Status symbols:
#   ◆/◇ (cyan)   current window (◇ = currently running)
#   ○   (yellow) running
#   ●   (yellow) unread — finished while not visible
#   ●   (green)  idle, nothing new since last visit
#
# Example output (after ANSI codes stripped):
#   @7 work:3 ◆ claude          [act 5s]
#   @2 work:1 ○ gemini          [act 0s]
#   @5 learn:0 ● codex [!]      [act 1m]
_ai_window_fzf_list() {
    local current_target="${1:-}"
    local now="${2:-$(date +%s)}"

    _ai_fzf_reset_session_colors

    while IFS=$'\t' read -r wvisit sess_win wname wid pane_pid wact_raw unread_flag running_flag attribute; do
        local sort_key status rel_visit rel_act time_info colored_sess_win
        local is_unread=0
        [[ "$unread_flag" == "1" ]] && is_unread=1

        local is_busy=false
        [[ "$running_flag" == "1" ]] && is_busy=true

        if [[ "$sess_win" == "$current_target" ]]; then
            sort_key=0
            if $is_busy; then
                status=$'\033[36m◇\033[0m '
            else
                status=$'\033[36m◆\033[0m '
            fi
        elif $is_busy; then
            sort_key=05
            status=$'\033[33m○\033[0m '
        elif (( is_unread )); then
            sort_key=08
            status=$'\033[33m●\033[0m '
        else
            sort_key=1
            status=$'\033[32m●\033[0m '
        fi

        rel_visit=$(_format_relative_age $((now - wvisit)))
        rel_act=$(_format_relative_age $((now - wact_raw)))
        _ai_fzf_colored_session_target "$sess_win" colored_sess_win

        if (( wvisit == wact_raw )); then
            time_info="[act ${rel_act}]"
        else
            time_info="[visit ${rel_visit} | act ${rel_act}]"
        fi

        local unread_mark=""
        (( is_unread )) && unread_mark=$' \033[33m[!]\033[0m'

        local attribute_info=""
        [[ -n "$attribute" ]] && attribute_info="  · ${attribute}"

        printf '%s\t%s\t%s %s %b%s%b  \033[2m%s%s\033[0m\n' \
            "$sort_key" "$wvisit" "$wid" "$colored_sess_win" "$status" "$wname" "$unread_mark" "$time_info" "$attribute_info"
    done |
    sort -t $'\t' -k1,1 -k2,2nr |
    cut -f3-
}
