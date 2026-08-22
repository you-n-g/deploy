#!/bin/bash
# Broker services: processes that hand out AI sessions on somebody else's behalf.
#
# cc-connect is one. It is a long-running node daemon, and the Claude sessions it
# serves are its own children -- so the pane it was started in looks like it
# holds a live AI process, and those sessions inherit its TMUX_PANE and fire
# their hooks against that pane. Left alone the pane gets renamed `● cc-connect`,
# parked with unread markers nobody will ever switch to and clear, and offered in
# every AI window picker. A pane running a broker is not an AI window, however
# many claude processes sit underneath it.
#
# The whole exclusion lives here so it stays pluggable: sourcing this file adds
# it, dropping the source line from ai/lib.sh removes it, and supporting another
# broker is a change to AI_SERVICE_PROC_NAME plus, if it launches differently,
# _ai_service_argv_matches.
#
# Exported predicates:
#   _ai_pid_under_service AI_PID PANE_PID
#       Is this AI process a session the broker handed out, rather than the agent
#       the pane belongs to? Used wherever the AI process is already known.
#   _pane_hosts_ai_service PANE_PID
#       Is a broker running anywhere under this pane? Used where there is no AI
#       process to start from.

AI_SERVICE_PROC_NAME='cc-connect'

# Does the argv of one process name a broker service?
#
# Matched on argv rather than on comm because the npm shim that starts cc-connect
# reports itself as `MainThread`, so only the command line identifies it -- but
# only on the program being run, never on the arguments. A plain substring test
# over the whole command line would classify `grep cc-connect` as a service and
# silently drop a real agent window out of every list.
_ai_service_argv_matches() {
    local argv0="${1:-}" argv1="${2:-}"

    case "${argv0##*/}" in
        "$AI_SERVICE_PROC_NAME") return 0 ;;
        node) [[ "${argv1##*/}" == "$AI_SERVICE_PROC_NAME" ]] && return 0 ;;
    esac

    return 1
}

# Is this AI process a session handed out by a broker service rather than the
# agent the pane belongs to? Walks from the process up to the pane root.
#
# Asking it this way instead of "does the pane contain a broker anywhere" keeps
# a pane that runs both -- an interactive agent started next to the daemon --
# correctly an AI pane. It is also a handful of /proc reads rather than a walk
# over the whole subtree, which for a live Claude is ~70 processes.
#
# Every read is a builtin: _ai_pane_rows calls this once per pane on every
# status-line and terminal-title refresh, and one $(...) per hop up the tree was
# enough to make that noticeably slower.
_ai_pid_under_service() {
    local pid="${1:?usage: _ai_pid_under_service AI_PID PANE_PID}"
    local pane_pid="${2:?usage: _ai_pid_under_service AI_PID PANE_PID}"
    local stat
    local -a argv

    while [[ -n "$pid" && "$pid" != "$pane_pid" && "$pid" != 1 ]]; do
        argv=()
        mapfile -d '' -t argv <"/proc/$pid/cmdline" 2>/dev/null
        _ai_service_argv_matches "${argv[0]:-}" "${argv[1]:-}" && return 0

        # Cut after the last ")" to skip comm, which can hold spaces and
        # parentheses -- node names its threads things like "Bun Pool 55". What
        # follows is "STATE PPID ...". Sliced rather than read into an array
        # because a herestring costs a temp file per hop.
        IFS= read -r stat <"/proc/$pid/stat" 2>/dev/null || return 1
        stat="${stat##*) }"
        stat="${stat#* }"
        pid="${stat%% *}"
    done

    return 1
}

# Is a broker service running in the subtree rooted at a pane PID?
#
# The subtree walk is the expensive answer, so it is only for callers that have
# no AI process to walk up from -- track_ai_agent_state.sh gating a hook event.
_pane_hosts_ai_service() {
    local root="${1:?usage: _pane_hosts_ai_service PANE_PID}"
    local queue=("$root")
    local seen=" "
    local pid children child
    local -a argv

    while ((${#queue[@]} > 0)); do
        pid="${queue[0]}"
        queue=("${queue[@]:1}")

        [[ "$seen" == *" $pid "* ]] && continue
        seen+="$pid "

        argv=()
        mapfile -d '' -t argv <"/proc/$pid/cmdline" 2>/dev/null
        _ai_service_argv_matches "${argv[0]:-}" "${argv[1]:-}" && return 0

        if [[ -r "/proc/$pid/task/$pid/children" ]]; then
            children=""
            IFS= read -r children <"/proc/$pid/task/$pid/children" || true
            for child in $children; do
                queue+=("$child")
            done
        fi
    done

    return 1
}
