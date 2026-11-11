_find_codex_remote_pid() {
    local root="$1"
    local queue=("$root")
    local seen=" "
    local pid children child args arg

    while ((${#queue[@]} > 0)); do
        pid="${queue[0]}"
        queue=("${queue[@]:1}")

        [[ "$seen" == *" $pid "* ]] && continue
        seen+="$pid "

        if [[ -r "/proc/$pid/cmdline" ]]; then
            args=()
            mapfile -d '' -t args <"/proc/$pid/cmdline" || true
            for arg in "${args[@]}"; do
                if [[ "$(basename -- "$arg")" == "codex-remote" ]]; then
                    printf '%s\n' "$pid"
                    return 0
                fi
            done
        fi

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

_codex_remote_fork_cmd() {
    local codex_remote_pid="$1"
    local session_id="$2"
    local cmdline=()
    local script_index=-1
    local script_path
    local args=()
    local preserved=()
    local target_index=-1
    local i arg

    mapfile -d '' -t cmdline <"/proc/$codex_remote_pid/cmdline"
    for i in "${!cmdline[@]}"; do
        if [[ "$(basename -- "${cmdline[$i]}")" == "codex-remote" ]]; then
            script_index="$i"
            break
        fi
    done
    [[ "$script_index" -ge 0 ]] || return 1

    script_path="${cmdline[$script_index]}"
    args=("${cmdline[@]:script_index + 1}")

    i=0
    while ((i < ${#args[@]})); do
        arg="${args[$i]}"
        case "$arg" in
            --)
                target_index=$((i + 1))
                break
                ;;
            --resume|--fork|--local-port|--remote-port)
                i=$((i + 2))
                ;;
            -C|--remote-cwd|-c|--config|--reconnect-delay|--codex-bin|--remote-codex-bin|--timeout)
                [[ $((i + 1)) -lt ${#args[@]} ]] || return 1
                preserved+=("$arg" "${args[$((i + 1))]}")
                i=$((i + 2))
                ;;
            --no-ai-status-bridge|--no-auto-reconnect)
                preserved+=("$arg")
                i=$((i + 1))
                ;;
            -*)
                return 1
                ;;
            *)
                target_index="$i"
                break
                ;;
        esac
    done
    [[ "$target_index" -ge 0 && "$target_index" -lt ${#args[@]} ]] || return 1

    tma_quote_command "$script_path" "${preserved[@]}" --fork "$session_id" "${args[@]:target_index}"
}
