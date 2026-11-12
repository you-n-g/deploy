# Batched process recognition stays in one shared fast path.
source "$TMA_WRAPPER_ROOT/default/broker_service.sh"
AI_PROC_PAT="(^|/)($(tma_backends | paste -sd '|' -))$"

_ai_proc_name_matches() { [[ "$1" =~ $AI_PROC_PAT ]]; }

# Gemini and Pi run as node/MainThread, so identify the entry point, not text in
# a prompt or an unrelated node program's arguments.
_node_ai_backend() {
    case "${1:-}" in node|*/node) shift ;; *) return 1 ;; esac
    while [[ "${1:-}" == -* ]]; do shift; done
    case "${1:-}" in
        gemini|*/bin/gemini|*/@google/gemini-cli/bundle/gemini.js) printf 'gemini\n' ;;
        pi|*/bin/pi|*/@earendil-works/pi-coding-agent/dist/cli.js|*/@earendil-works/pi-coding-agent/dist/bundle/cli.js) printf 'pi\n' ;;
        *) return 1 ;;
    esac
}

_find_ai_pid_procfs() {
    local root="$1"
    local queue=("$root")
    local seen=" "
    local pid comm children child backend
    local -a argv

    while ((${#queue[@]} > 0)); do
        pid="${queue[0]}"
        queue=("${queue[@]:1}")

        [[ "$seen" == *" $pid "* ]] && continue
        seen+="$pid "

        if [[ -r "/proc/$pid/comm" ]]; then
            comm=""
            IFS= read -r comm <"/proc/$pid/comm" || true
            if [[ "$comm" == node || "$comm" == MainThread ]]; then
                argv=()
                mapfile -d '' -t argv <"/proc/$pid/cmdline" 2>/dev/null || continue
                if backend="$(_node_ai_backend "${argv[@]}")"; then comm="$backend"; fi
            fi
            if _ai_proc_name_matches "$comm"; then
                printf '%s %s\n' "$pid" "$comm"
                return 0
            fi
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

# Find the first AI process in the subtree rooted at a pane PID.
# Prints "PID COMM" (e.g. "12345 claude") and returns 0, or returns 1 if none.
# For loops, pass one process snapshot to avoid repeated process-table scans:
#   ps_cache=$(_ai_process_snapshot)
#   _has_ai_proc "$pane_pid" "$ps_cache"
_find_ai_pid() {
    if [[ $# -lt 2 && -r "/proc/$1/task/$1/children" ]]; then
        _find_ai_pid_procfs "$1"
        return
    fi

    local ps_data="${2:-$(_ai_process_snapshot)}"
    echo "$ps_data" | awk -v root="$1" -v pat="$AI_PROC_PAT" '
        { children[$2] = children[$2] " " $1; name[$1] = $3 }
        END {
            q[1] = root
            n = 1
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
# This answers "is this an AI window?" one pane at a time; _ai_pane_rows answers
# it in batch. Both have to apply lib/broker_service.sh, or a broker pane drops
# out of the renames but stays in the pickers.
_has_ai_proc() {
    local found

    if [[ $# -ge 2 ]]; then
        found="$(_find_ai_pid "$1" "$2")" || return 1
    else
        found="$(_find_ai_pid "$1")" || return 1
    fi

    ! _ai_pid_under_service "${found%% *}" "$1"
}

# Print PANE_PID<TAB>AI_PID in one scan; callers apply broker exclusion using
# the AI pid because the compact snapshot has no argv for that decision.
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
                    found[current "\t" pid] = 1
                    break
                }
                current = parent[current]
            }
        }
        for (pair in found) print pair
    }
    ' <(printf '%s\n' "$pane_pids") <(printf '%s\n' "$ps_data")
}

_ai_process_snapshot() {
    if [[ -r /proc/1/stat ]]; then
        perl -e '
            for my $stat_file (glob "/proc/[0-9]*/stat") {
                open my $fh, "<", $stat_file or next;
                my $line = <$fh>;
                next unless defined $line;
                next unless $line =~ /^(\d+) \((.*)\) \S+ (\d+) /;
                my ($pid, $name, $parent) = ($1, $2, $3);
                if ($name eq "node" || $name eq "MainThread") {
                    if (open my $cmd, "<", "/proc/$pid/cmdline") {
                        local $/;
                        my @args = split /\0/, <$cmd>;
                        my $exe = shift @args;
                        shift @args while @args && $args[0] =~ /^-/;
                        if ($exe =~ m{(^|/)node$} && @args &&
                            $args[0] =~ m{^(gemini|.*/bin/gemini|.*/\@google/gemini-cli/bundle/gemini\.js)$}) {
                            $name = "gemini";
                        }
                        if ($exe =~ m{(^|/)node$} && @args &&
                            $args[0] =~ m{^(pi|.*/bin/pi|.*/\@earendil-works/pi-coding-agent/dist/(bundle/)?cli\.js)$}) {
                            $name = "pi";
                        }
                    }
                }
                print "$pid $parent $name\n";
            }
        '
    else
        ps -ax -o pid=,ppid=,comm=,args= | awk '
            $4 ~ /(^|\/)node$/ {
                for (i = 5; i <= NF && $i ~ /^-/; i++) {}
                if ($i ~ /^(gemini|.*\/bin\/gemini|.*\/@google\/gemini-cli\/bundle\/gemini\.js)$/) $3 = "gemini"
                if ($i ~ /^(pi|.*\/bin\/pi|.*\/@earendil-works\/pi-coding-agent\/dist\/(bundle\/)?cli\.js)$/) $3 = "pi"
            }
            { print $1, $2, $3 }
        '
    fi
}
