#!/bin/bash
# Shared helpers for AI window detection

AI_PROC_PAT='(^|/)(claude|gemini|codex)$'
_AI_UNREAD_THRESHOLD=5  # consecutive running samples before marking a window unread
_AI_FZF_PREVIEW_HEIGHT=85%  # fzf preview-window height for AI-window selectors
_AI_FZF_SESSION_COLOR_CODES=(31 32 33 34 35 36 91 92 93 94 95 96)
declare -A _ai_fzf_session_colors=()
declare -A _ai_fzf_used_session_colors=()

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

_ai_fzf_reset_session_colors() {
    _ai_fzf_session_colors=()
    _ai_fzf_used_session_colors=()
}

_ai_fzf_session_color_code() {
    local session_name="$1"
    local out_var="$2"
    local color="${_ai_fzf_session_colors[$session_name]}"
    local checksum start offset candidate color_count

    [[ -n "$color" ]] && { printf -v "$out_var" '%s' "$color"; return; }

    color_count="${#_AI_FZF_SESSION_COLOR_CODES[@]}"
    checksum=$(printf '%s' "$session_name" | cksum)
    checksum="${checksum%% *}"
    start=$((checksum % color_count))

    for ((offset = 0; offset < color_count; offset++)); do
        candidate="${_AI_FZF_SESSION_COLOR_CODES[$(((start + offset) % color_count))]}"
        if [[ -z "${_ai_fzf_used_session_colors[$candidate]}" ]]; then
            color="$candidate"
            break
        fi
    done

    [[ -z "$color" ]] && color="${_AI_FZF_SESSION_COLOR_CODES[$start]}"
    _ai_fzf_session_colors[$session_name]="$color"
    _ai_fzf_used_session_colors[$color]=1
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

# Print unique AI windows as tab-separated rows, sorted by last_visit desc.
# Also maintains per-window unread state in ~/.tmux/ai_unread_state.
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
#   $6 window_activity epoch of last output
#   $7 unread_flag     1 if >= _AI_UNREAD_THRESHOLD consecutive running samples
#                      occurred after last_visit and window is now idle; else 0
#
# Example output:
#   1745000100  work:3   claude   @7   12345   1745000099   1
#   1744999800  work:1   gemini   @2   67890   1744999800   0
_ai_window_rows() {
    local now state_file tmp_file
    now=$(date +%s)
    state_file="${HOME}/.tmux/ai_unread_state"
    tmp_file="${state_file}.${BASHPID:-$$}"

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
    awk -F '\t' '!seen[$4]++' |
    awk -v now="$now" -v thr="${_AI_UNREAD_THRESHOLD}" -v sf="$state_file" -v tf="$tmp_file" -F '\t' '
    BEGIN {
        while ((getline line < sf) > 0) {
            n = split(line, a, ":")
            if (n >= 4) { cr[a[1]]=a[2]+0; uf[a[1]]=a[3]+0; lvs[a[1]]=a[4]+0 }
        }
        close(sf); printf "" > tf
    }
    {
        wvisit=$1+0; wid=$4; wact=$6+0
        c=cr[wid]+0; u=uf[wid]+0; l=lvs[wid]+0
        if (wvisit > l) { c=0; u=0 }
        is_run = ((now-wact)<=1 && wact>wvisit) ? 1 : 0
        if (is_run) { if (++c >= thr) u=1 } else { c=0 }
        print wid ":" c ":" u ":" wvisit > tf
        print $0 "\t" u
    }
    END { close(tf) }
    '

    [[ -f "$tmp_file" ]] && mv -f "$tmp_file" "$state_file" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
}

# Format for tmux status bar: "N" normally, "N !M" when M windows are waiting.
# The current window is excluded from both counts — the user already knows about it.
_ai_status_label() {
    local now r w cur
    now=$(date +%s)
    cur=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)
    read -r r w < <(_ai_window_rows -a | awk -F '\t' -v now="$now" -v cur="$cur" '
        $2 == cur      { next }
        { is_run = (now - $6+0) <= 1 }
        is_run         { running++ }
        $7==1 && !is_run { waiting++ }
        END { print running+0 " " waiting+0 }
    ')
    if   (( w > 0 && r > 0 )); then printf '%d !%d' "$r" "$w"
    elif (( w > 0 ));           then printf '!%d' "$w"
    else                             printf '%d' "$r"
    fi
}

# Count AI windows that are actively producing output right now.
_ai_running_count() {
    local now
    now=$(date +%s)
    _ai_window_rows -a | awk -F '\t' -v now="$now" '(now - $6) <= 1 { c++ } END { print c+0 }'
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
#   ○   (yellow) running (activity within last 1s)
#   ●   (yellow) unread — was running after last visit, now idle
#   ●   (green)  idle, nothing new since last visit
#
# Example output (after ANSI codes stripped):
#   @7 work:3 ◆ claude          [visit 2s | act 5s]
#   @2 work:1 ○ gemini          [act 0s]
#   @5 learn:0 ● codex [!]      [visit 3m | act 1m]
_ai_window_fzf_list() {
    local current_target="${1:-}"
    local now="${2:-$(date +%s)}"

    _ai_fzf_reset_session_colors

    while IFS=$'\t' read -r wvisit sess_win wname wid pane_pid wact_raw unread_flag; do
        local sort_key status rel_visit rel_act time_info colored_sess_win
        local is_unread=0
        [[ "$unread_flag" == "1" ]] && is_unread=1

        local is_busy=false
        (( now - wact_raw <= 1 )) && is_busy=true

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

        printf '%s\t%s\t%s %s %b%s%b  \033[2m%s\033[0m\n' \
            "$sort_key" "$wvisit" "$wid" "$colored_sess_win" "$status" "$wname" "$unread_mark" "$time_info"
    done |
    sort -t $'\t' -k1,1 -k2,2nr |
    cut -f3-
}
