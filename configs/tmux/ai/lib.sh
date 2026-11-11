#!/bin/bash
# Shared helpers for AI window detection

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../wrapper/dispatch.sh"

TMUXG_SHOW_ORCHESTRATOR_OPTION="@tmuxg-show-orchestrator"
TMUX_SEND_TARGET_SHOW_ORCHESTRATOR_OPTION="@tmux-send-target-show-orchestrator"
TMUXG_SESSION_BLACKLIST_REGEX_OPTION="@tmuxg-session-blacklist-regex"
_AI_FZF_PREVIEW_HEIGHT=85%  # fzf preview-window height for AI-window selectors
_AI_FZF_SESSION_COLOR_CODES=(31 32 33 34 35 36 91 92 93 94 95 96)

_ai_session_id_for_pane() {
    local pane_id="${1:?usage: _ai_session_id_for_pane PANE_ID}"
    local pane_pid result ai_pid ai_name

    pane_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}') || return 1
    result=$(_find_ai_pid "$pane_pid") || return 1
    ai_pid="${result%% *}"
    ai_name=$(basename "${result##* }")

    tma_call "$ai_name" session_id "$ai_pid" "$pane_id"
}

_find_ai_pane_in_window() {
    local window_id="$1"
    local pane_rows ps_cache
    local pane_id pane_pid pane_active
    local first_ai_pane=""

    pane_rows=$(tmux list-panes -t "$window_id" -F $'#{pane_id}\t#{pane_pid}\t#{pane_active}' 2>/dev/null) || return 1
    ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null) || return 1

    while IFS=$'\t' read -r pane_id pane_pid pane_active; do
        [[ -z "$pane_id" || -z "$pane_pid" ]] && continue
        if _has_ai_proc "$pane_pid" "$ps_cache"; then
            if [[ "$pane_active" == "1" ]]; then
                printf '%s\n' "$pane_id"
                return 0
            fi
            [[ -z "$first_ai_pane" ]] && first_ai_pane="$pane_id"
        fi
    done <<< "$pane_rows"

    [[ -n "$first_ai_pane" ]] || return 1
    printf '%s\n' "$first_ai_pane"
}

_ai_reset_pane_attribute_in_window() {
    local target="${1:?usage: _ai_reset_pane_attribute_in_window TARGET}"
    local pane_id
    local script_dir

    if ! pane_id="$(_find_ai_pane_in_window "$target")" || [[ -z "$pane_id" ]]; then
        tmux display-message "Failed to find an AI pane in $target"
        return 1
    fi

    if ! tmux set-option -pqu -t "$pane_id" @ai_agent_attribute; then
        tmux display-message "Failed to reset AI attribute for $pane_id"
        return 1
    fi

    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    if ! "$script_dir/../script/refresh_status_lines.sh" "$pane_id"; then
        tmux display-message "Failed to refresh tmux status for $pane_id"
        return 1
    fi
}

_tmux_current_target() {
    if [[ -n "$TMUX" ]]; then
        tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null
    fi
}

_format_relative_age() {
    local diff="$1"
    local out_var="$2"
    local formatted

    if   (( diff < 60 ));    then formatted="${diff}s"
    elif (( diff < 3600 ));  then formatted="$((diff / 60))m"
    elif (( diff < 86400 )); then formatted="$((diff / 3600))h"
    else                          formatted="$((diff / 86400))d"
    fi

    printf -v "$out_var" '%s' "$formatted"
}

# Pane ids marked done (@ai_agent_done), one per line. _ai_pane_rows has no
# column for it: its readers split positionally and the last column takes the
# rest of the line, so callers look panes up in this set instead.
_ai_done_pane_ids() {
    tmux list-panes -a -F '#{?@ai_agent_done,#{pane_id},}' 2>/dev/null | grep . || true
}

# Pane ids in windows a TMA agent made (@tma_created, a window option), looked
# up the same way as _ai_done_pane_ids.
_ai_tma_pane_ids() {
    tmux list-panes -a -F '#{?@tma_created,#{pane_id},}' 2>/dev/null | grep . || true
}

# Pane ids unread because they were released from pending (@ai_agent_woke),
# looked up the same way as _ai_done_pane_ids.
_ai_woke_pane_ids() {
    tmux list-panes -a -F '#{?@ai_agent_woke,#{pane_id},}' 2>/dev/null | grep . || true
}

_ai_pending_reason_label() {
    local pending="$1"
    local out_var="$2"
    local label

    if [[ "$pending" == "1" ]]; then
        label="/"
    else
        label="$pending"
    fi

    printf -v "$out_var" '%s' "$label"
}

# The orchestrator window is the one named "orchestrator". Whether it takes part
# in AI listings and notifications (pickers, status counts, terminal title,
# window summary, task-done toast) is decided by one switch,
# _tmuxg_show_orchestrator_enabled below. Ask _ai_window_participates for one
# window; in a loop over rows, read the switch once and ask
# _ai_window_is_orchestrator per row.
_ai_window_is_orchestrator() {
    [[ "$1" == "orchestrator" ]]
}

_ai_window_participates() {
    ! _ai_window_is_orchestrator "$1" || _tmuxg_show_orchestrator_enabled
}

_tmuxg_show_orchestrator_enabled() {
    local value

    value="$(tmux show-options -gqv "$TMUXG_SHOW_ORCHESTRATOR_OPTION" 2>/dev/null || true)"
    case "$value" in
        ""|1|on|true|yes) return 0 ;;
        0|off|false|no) return 1 ;;
        *)
            echo "Invalid ${TMUXG_SHOW_ORCHESTRATOR_OPTION}: ${value}" >&2
            exit 1
            ;;
    esac
}

_tmuxg_orchestrator_visibility_label() {
    if _tmuxg_show_orchestrator_enabled; then
        printf 'show\n'
    else
        printf 'hide\n'
    fi
}

_tmuxg_toggle_orchestrator_visibility() {
    local next label script_dir session context

    if _tmuxg_show_orchestrator_enabled; then
        next=0
        label=hidden
    else
        next=1
        label=shown
    fi

    tmux set-option -gq "$TMUXG_SHOW_ORCHESTRATOR_OPTION" "$next"
    context=tmuxg
    if [[ "$TMUXG_SHOW_ORCHESTRATOR_OPTION" == "$TMUX_SEND_TARGET_SHOW_ORCHESTRATOR_OPTION" ]]; then
        context="send target"
    fi
    tmux display-message "${context} orchestrator: ${label}"
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    session="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"
    if [[ -n "$session" ]]; then
        "$script_dir/../script/refresh_status_lines.sh" "$session" >/dev/null 2>&1 || true
    fi
}

_tmuxg_filter_orchestrator_rows() {
    local last_visit sess_win wname pane_id pane_pid wact_raw unread running background pending pane_path attribute

    if _tmuxg_show_orchestrator_enabled; then
        cat
        return
    fi

    while IFS=$'\t' read -r last_visit sess_win wname pane_id pane_pid wact_raw unread running background pending pane_path attribute; do
        _ai_window_is_orchestrator "$wname" && continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$last_visit" "$sess_win" "$wname" "$pane_id" "$pane_pid" "$wact_raw" "$unread" "$running" "$background" "$pending" "$pane_path" "$attribute"
    done
}

_tmuxg_session_blacklist_regexes() {
    tmux show-options -gqv "$TMUXG_SESSION_BLACKLIST_REGEX_OPTION" 2>/dev/null || true
}

_tmuxg_session_is_blacklisted() {
    local session_name="$1"
    local blacklist_regexes="$2"
    local blacklist_regex match_status

    for blacklist_regex in $blacklist_regexes; do
        [[ -n "$blacklist_regex" ]] || continue
        if [[ "$session_name" =~ $blacklist_regex ]]; then
            return 0
        else
            match_status=$?
            if (( match_status == 2 )); then
                echo "Invalid ${TMUXG_SESSION_BLACKLIST_REGEX_OPTION}: ${blacklist_regex}" >&2
                exit 1
            fi
        fi
    done

    return 1
}

_tmuxg_filter_blacklisted_session_rows() {
    local blacklist_regexes

    blacklist_regexes="$(_tmuxg_session_blacklist_regexes)"
    if [[ -z "$blacklist_regexes" ]]; then
        cat
        return
    fi

    awk -F '\t' -v regexes="$blacklist_regexes" '
        BEGIN {
            OFS = FS
            regex_count = split(regexes, blacklist_regexes, /[[:space:]]+/)
        }
        {
            session_name = $2
            sub(/:.*/, "", session_name)
            for (i = 1; i <= regex_count; i++) {
                if (blacklist_regexes[i] != "" && session_name ~ blacklist_regexes[i]) {
                    next
                }
            }
            print
        }
    '
}

_clear_ai_pane_state() {
    local pane_id="${1:?usage: _clear_ai_pane_state PANE_ID}"

    tmux set-option -pqu -t "$pane_id" @ai_agent_running 2>/dev/null || true
    tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
    tmux set-option -pqu -t "$pane_id" @ai_agent_unread 2>/dev/null || true
    tmux set-option -pqu -t "$pane_id" @ai_agent_woke 2>/dev/null || true
    tmux set-option -pqu -t "$pane_id" @ai_agent_attribute 2>/dev/null || true
}

_ai_ranked_pane_id_set() {
    local ranked candidate resolved seen=""

    ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
    for candidate in $ranked; do
        [[ "$candidate" == %* ]] || continue
        resolved="$candidate"
        case " $seen " in
            *" $resolved "*) continue ;;
        esac
        seen="${seen:+$seen }$resolved"
    done

    printf ' %s ' "$seen"
}

# Print unique AI panes as tab-separated rows, sorted by last_visit desc.
#
# Usage: _ai_pane_rows [-a] [-s -t SESSION] [tmux list-panes options]
#   -a              scan all sessions
#   -s -t SESSION   scan a specific session only
#
# Output columns (TAB-separated):
#   $1 last_visit      epoch of last user visit (falls back to window_activity)
#   $2 session:index.pane   e.g. "work:3.0"
#   $3 window_name     e.g. "claude"
#   $4 pane_id         e.g. "%12"
#   $5 pane_pid        root PID of the pane
#   $6 activity_epoch  tmux window activity
#   $7 unread_flag     1 if the agent finished while not visible
#   $8 running_flag    1 if the agent hook says this window is running
#   $9 background_flag 1 if Claude paused with background work still active
#   $10 pending_reason 0 if not pending; otherwise the pending reason
#   $11 pane_current_path
#   $12 attribute      short description generated once after first stop
_ai_pane_rows() {
    local pane_rows pane_pids ai_pane_pids

    pane_rows=$(tmux list-panes "$@" \
        -F $'#{?@last_visit,#{@last_visit},#{window_activity}}\t#{session_name}:#{window_index}.#{pane_index}\t#{window_name}\t#{window_id}\t#{pane_id}\t#{pane_pid}\t#{pane_active}\t#{window_activity}\t#{@ai_agent_unread}\t#{@ai_agent_running}\t#{@ai_agent_background}\t#{@ai_agent_pending}\t#{pane_current_path}\t#{@ai_agent_attribute}' 2>/dev/null) || return 1
    pane_pids=$(printf '%s\n' "$pane_rows" | awk -F '\t' '{ print $6 }')
    # Shared batch recognition includes broker exclusion and backend process
    # rules. On Linux it only visits pane subtrees, stopping at each agent.
    ai_pane_pids="$(tma_call default ai_pane_pids "$pane_pids")" || return

    awk -F '\t' '
        FNR == NR {
            if ($1 != "") has_ai_proc_by_pane[$1] = 1
            next
        }
        has_ai_proc_by_pane[$6] {
            attribute = $14
            for (i = 15; i <= NF; i++) attribute = attribute " " $i
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, attribute
        }
    ' <(printf '%s\n' "$ai_pane_pids") <(printf '%s\n' "$pane_rows") |
    sort -t $'\t' -k1,1nr -k8,8nr -k7,7nr |
    awk -F '\t' '!seen[$5]++' |
    awk -F '\t' '
    {
        pending = $12
        if (pending == "") pending = "0"
        print $1+0 "\t" $2 "\t" $3 "\t" $5 "\t" $6 "\t" $8+0 "\t" $9+0 "\t" $10+0 "\t" $11+0 "\t" pending "\t" $13 "\t" $14
    }
    '
}

# Format _ai_pane_rows output (read from stdin) into fzf-ready lines.
#
# Usage: _ai_pane_rows [-a] | _ai_pane_fzf_list [current_target [now]]
#   current_target   session:index.pane of the current pane, e.g. "work:3.0"
#   now              epoch seconds (defaults to $(date +%s))
#
# Output columns (SPACE-separated, ready for fzf --ansi):
#   $1 pane_id        e.g. "%12"
#   $2 session:index.pane  e.g. "work:3.0" (session name is ANSI-colored)
#   $3+  ANSI label   status-symbol + window_name + unread mark + time info + pane id marker
#
# Status symbols:
#   ▶/➲/▷ (cyan) current pane (▶ = running, ➲ = background, ▷ = idle)
#   ✓   (green)  done -- the pane was marked done (current pane too)
#   ●   (yellow) running
#   ◒   (yellow) Claude background work
#   ◓   (yellow) background work, and a turn ended out of sight (unread)
#   ⏸   (magenta) pending — intentionally waiting on something
#   ◉   (yellow) unread — finished while not visible
#   ☀   (yellow) unread — released from pending (dependency or snooze) out of sight
#   ○   (green)  idle, nothing new since last visit
#   [agent] (cyan) after the window name: a TMA agent made the window
#
# Example output (after ANSI codes stripped):
#   %12 work:3.0 ▶ claude          [act 5s]  [pane %12]
#   %13 work:3.1 ● gemini          [act 0s]  [pane %13 marked switcher]
#   %14 learn:0.0 ◉ codex          [act 1m] [unread]  [pane %14]
_ai_pane_fzf_list() {
    local current_target="${1:-}" now="${2:-$(date +%s)}"
    local switcher_pane_id ranked_pane_ids metadata script_dir

    switcher_pane_id="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"
    if [[ -n "$switcher_pane_id" ]]; then
        switcher_pane_id="$(tmux display-message -p -t "$switcher_pane_id" '#{pane_id}' 2>/dev/null || true)"
    fi
    ranked_pane_ids="$(_ai_ranked_pane_id_set)"
    metadata="$(tmux list-panes -a -F $'#{pane_id}\t#{pane_marked}\t#{?@ai_agent_done,1,0}\t#{?@ai_agent_woke,1,0}\t#{?@ai_agent_muted,1,0}\t#{?@tma_created,1,0}')" || return
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

    awk -v current="$current_target" -v now="$now" -v switcher="$switcher_pane_id" \
        -v ranked="$ranked_pane_ids" -v palette="${_AI_FZF_SESSION_COLOR_CODES[*]}" \
        -v preserve="${AI_PANE_FZF_PRESERVE_ORDER:-0}" -f "$script_dir/pane_list.awk" \
        <(printf '%s\n' "$metadata") - |
        sort -t $'\t' -k1,1 -k2,2nr |
        cut -f3-
}
