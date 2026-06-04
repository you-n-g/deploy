#!/bin/bash
# Find the pane running an AI agent in a tmux session.
# If multiple AI panes exist, show fzf to pick one.
# Works in both interactive and non-interactive (run-shell) contexts.
#
# Usage: ./get_ai_pane.sh [-i] [-a] [-A] [session_name]
# -i: return pane_id instead of session.window.pane
# -a: list ALL AI panes (one per line), skip interactive selection
# -A: scan across all tmux sessions (ignores [session_name])
# Ctrl-O in the fzf picker toggles whether the orchestrator window is shown.
#
# Exit codes:
#   0  success (pane found/selected)
#   1  no AI panes found
#   2  user canceled selection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/lib.sh"

_current_target() {
    if [[ -n "$TMUX" ]]; then
        tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null
    fi
}

_pane_target() {
    local pane_id="${1:?usage: _pane_target PANE_ID}"
    tmux display-message -t "$pane_id" -p '#{session_name}.#{window_index}.#{pane_index}' 2>/dev/null
}

_output_pane() {
    local pane_id="${1:?usage: _output_pane PANE_ID}"
    local pane_target

    if [[ "$RETURN_ID" == true ]]; then
        printf '%s\n' "$pane_id"
    else
        pane_target=$(_pane_target "$pane_id")
        if [[ -z "$pane_target" ]]; then
            echo "Failed to format AI pane target for $pane_id" >&2
            exit 1
        fi
        printf '%s\n' "$pane_target"
    fi
}

_get_ai_pane_rows() {
    local rows

    if [[ "$ALL_SESSIONS" == true ]]; then
        rows="$(_ai_pane_rows -a)" || return 1
    else
        rows="$(_ai_pane_rows -s -t "$SESSION")" || return 1
    fi

    [[ -n "$rows" ]] || return 0
    printf '%s\n' "$rows" | _tmuxg_filter_orchestrator_rows
}

_get_fzf_list() {
    local current_target rows

    current_target="$(_current_target)"
    rows=$(_get_ai_pane_rows)
    [[ -n "$rows" ]] || return 1

    printf '%s\n' "$rows" | _ai_pane_fzf_list "$current_target" "$(date +%s)"
}

_switcher_header_info() {
    local switcher pane_id pane_target

    switcher="$(tmux show-option -gqv @tma_window_switcher_pane 2>/dev/null || true)"
    if [[ -z "$switcher" ]]; then
        printf 'none\n'
        return
    fi

    pane_id="$(tmux display-message -p -t "$switcher" '#{pane_id}' 2>/dev/null || true)"
    if [[ -z "$pane_id" ]]; then
        printf 'stale %s\n' "$switcher"
        return
    fi

    pane_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
    if [[ -n "$pane_target" ]]; then
        printf '%s %s\n' "$pane_id" "$pane_target"
    else
        printf '%s\n' "$pane_id"
    fi
}

_fzf_header() {
    printf '▶ current pane busy  ➲ current Claude background  ◒ Claude background  ▷ current pane idle  ● busy  ◉ unread  ○ idle  |  orchestrator: %s  |  switcher: %s  |  Enter switch  Ctrl-R reset desc  Ctrl-O toggle orchestrator\n' \
        "$(_tmuxg_orchestrator_visibility_label)" \
        "$(_switcher_header_info)"
}

_reset_pane_attribute() {
    local pane_id="${1:?usage: _reset_pane_attribute PANE_ID}"

    if ! tmux set-option -pqu -t "$pane_id" @ai_agent_attribute; then
        tmux display-message "Failed to reset AI attribute for $pane_id"
        return 1
    fi

    if ! "$SCRIPT_DIR/../script/refresh_status_lines.sh" "$pane_id"; then
        tmux display-message "Failed to refresh tmux status for $pane_id"
        return 1
    fi
}

RETURN_ID=false
LIST_ALL=false
ALL_SESSIONS=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -i) RETURN_ID=true; shift ;;
        -a) LIST_ALL=true; shift ;;
        -A) ALL_SESSIONS=true; shift ;;
        --fzf-list)
            shift
            if [[ "${1:-}" == "-A" ]]; then
                ALL_SESSIONS=true
                shift
            fi

            SESSION=${1:-$(tmux display-message -p '#S' 2>/dev/null)}
            [[ "$ALL_SESSIONS" == true || -n "$SESSION" ]] || exit 1
            _get_fzf_list
            exit 0
            ;;
        --reset-pane-attribute)
            if [[ -z "$2" ]]; then
                echo "--reset-pane-attribute requires a target" >&2
                exit 2
            fi
            _reset_pane_attribute "$2"
            exit $?
            ;;
        --fzf-header)
            _fzf_header
            exit 0
            ;;
        --toggle-orchestrator-visibility)
            _tmuxg_toggle_orchestrator_visibility
            exit 0
            ;;
        *)  shift ;;
    esac
done

SESSION=${1:-$(tmux display-message -p '#S' 2>/dev/null)}
if [[ "$ALL_SESSIONS" != true ]]; then
    [[ -z "$SESSION" ]] && exit 1
fi

ROWS=$(_get_ai_pane_rows)
[[ -n "$ROWS" ]] || exit 1

if [[ "$LIST_ALL" == true ]]; then
    while IFS=$'\t' read -r _last_visit _sess_win wname pane_id _pane_pid _wact_raw _unread _running _background _attribute; do
        if [[ "$RETURN_ID" == true ]]; then
            printf '%s\n' "$pane_id"
        else
            pane_target=$(_pane_target "$pane_id")
            if [[ -z "$pane_target" ]]; then
                echo "Failed to format AI pane target for $pane_id" >&2
                exit 1
            fi
            printf '%s (%s)\n' "$pane_target" "$wname"
        fi
    done <<< "$ROWS"
    exit 0
fi

COUNT=$(echo "$ROWS" | wc -l | tr -d ' ')

if [[ "$COUNT" -eq 1 ]]; then
    IFS=$'\t' read -r _last_visit _sess_win _wname pane_id _pane_pid _wact_raw _unread _running _background _attribute <<< "$ROWS"
    _output_pane "$pane_id"
    exit 0
fi

LIST=$(echo "$ROWS" | _ai_pane_fzf_list "$(_current_target)")

LISTFILE=$(mktemp)
trap "rm -f '$LISTFILE'" EXIT
printf '%s\n' "$LIST" > "$LISTFILE"

printf -v RESET_BIND_CMD '%q --reset-pane-attribute {1}' "$SCRIPT_DIR/get_ai_pane.sh"
if [[ "$ALL_SESSIONS" == true ]]; then
    printf -v RELOAD_BIND_CMD '%q --fzf-list -A' "$SCRIPT_DIR/get_ai_pane.sh"
else
    printf -v RELOAD_BIND_CMD '%q --fzf-list %q' "$SCRIPT_DIR/get_ai_pane.sh" "$SESSION"
fi
RESET_ATTRIBUTE_BIND="ctrl-r:execute-silent($RESET_BIND_CMD)+reload($RELOAD_BIND_CMD)+refresh-preview"
printf -v TOGGLE_ORCHESTRATOR_BIND_CMD '%q --toggle-orchestrator-visibility' "$SCRIPT_DIR/get_ai_pane.sh"
printf -v FZF_HEADER_CMD '%q --fzf-header' "$SCRIPT_DIR/get_ai_pane.sh"
TOGGLE_ORCHESTRATOR_BIND="ctrl-o:execute-silent($TOGGLE_ORCHESTRATOR_BIND_CMD)+reload($RELOAD_BIND_CMD)+transform-header($FZF_HEADER_CMD)+refresh-preview"
HEADER="$(_fzf_header)"
printf -v HEADER_ARG '%q' "$HEADER"

START_POS=$(
    printf '%s\n' "$LIST" |
        perl -pe 's/\e\[[0-9;]*m//g' |
        awk '
            /\[!\]/ && unread == 0 { unread = NR }
            $3 == "○" && ready == 0 { ready = NR }
            END {
                if (unread > 0) print unread
                else if (ready > 0) print ready
                else print 1
            }
        '
)

START_BIND_ARGS=()
START_BIND_CMD=""
if (( START_POS > 1 )); then
    START_BIND_ARGS=(--bind "load:pos($START_POS)")
    printf -v START_BIND_CMD ' --bind %q' "load:pos($START_POS)"
fi

if [[ -t 0 ]]; then
    SELECTED=$(fzf --ansi --reverse \
        "${START_BIND_ARGS[@]}" \
        --with-nth '2..' \
        --header "$HEADER" \
        --bind "$RESET_ATTRIBUTE_BIND" \
        --bind "$TOGGLE_ORCHESTRATOR_BIND" \
        --preview 'tmux capture-pane -ept {1} | perl -0777 -pe "s/\s+\z/\n/"' \
        --preview-window "up:${_AI_FZF_PREVIEW_HEIGHT},follow" < "$LISTFILE")
else
    RESULTFILE=$(mktemp)
    CHANNEL="get_ai_pane_$$"
    trap "rm -f '$LISTFILE' '$RESULTFILE'" EXIT

    tmux display-popup -E -w 100% -h 100% "\
        trap 'tmux wait-for -S \"$CHANNEL\"' EXIT; \
        fzf --ansi --reverse \
            $START_BIND_CMD \
            --with-nth '2..' \
            --header $HEADER_ARG \
            --bind '$RESET_ATTRIBUTE_BIND' \
            --bind '$TOGGLE_ORCHESTRATOR_BIND' \
            --preview 'tmux capture-pane -ept {1} | perl -0777 -pe \"s/\s+\z/\n/\"' \
            --preview-window 'up:${_AI_FZF_PREVIEW_HEIGHT},follow' < '$LISTFILE' > '$RESULTFILE'"

    tmux wait-for "$CHANNEL"
    SELECTED=$(cat "$RESULTFILE")
fi

[[ -z "$SELECTED" ]] && exit 2
PANE_ID=$(echo "$SELECTED" | cut -d' ' -f1)
_output_pane "$PANE_ID"
