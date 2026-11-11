_AI_CODEX_SESSION_ID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
_first_codex_session_id() {
    grep -oE "$_AI_CODEX_SESSION_ID_RE" | head -1 || true
}

_codex_session_id_from_args() {
    ps -p "$1" -o args= 2>/dev/null | _first_codex_session_id
}

_codex_session_id_from_proc_fd() {
    find "/proc/$1/fd" -maxdepth 1 -type l -printf '%l\n' 2>/dev/null |
        _first_codex_session_id
}

_codex_session_id_from_lsof() {
    local lsof_output

    if command -v timeout >/dev/null 2>&1; then
        lsof_output=$(timeout 3 lsof -p "$1" 2>/dev/null || true)
    else
        lsof_output=$(lsof -p "$1" 2>/dev/null || true)
    fi
    printf '%s\n' "$lsof_output" | awk '{print $NF}' | _first_codex_session_id
}

_codex_session_id_for_pid() {
    local ai_pid="${1:?usage: _codex_session_id_for_pid AI_PID}"
    local session_id=""

    # Forked Codex keeps the source id in argv; the open jsonl fd is active.
    if [[ -d "/proc/$ai_pid/fd" ]]; then
        session_id=$(_codex_session_id_from_proc_fd "$ai_pid")
    fi
    if [[ -z "$session_id" ]] && command -v lsof >/dev/null 2>&1; then
        session_id=$(_codex_session_id_from_lsof "$ai_pid")
    fi
    if [[ -z "$session_id" ]]; then
        session_id=$(_codex_session_id_from_args "$ai_pid")
    fi

    [[ -n "$session_id" ]] || return 1
    printf '%s\n' "$session_id"
}
