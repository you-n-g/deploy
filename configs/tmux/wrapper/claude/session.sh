# Claude Code tracks each live session in <config>/sessions/<pid>.json. Unlike
# older versions, that file stays current: `sessionId` is rewritten on /clear,
# and status/updatedAt are refreshed as the session runs. It also records the
# owning tmux pane and the process start time, both of which we verify so a
# stale file from a recycled pid can't hand back the wrong session.
# The file only appears once the session has real content, so a freshly started
# claude with no turns yet legitimately has no id to report.
#
# `sessionId` is not always the conversation on screen, though. When the session
# parks itself on a background job the pane keeps showing the job -- that is what
# the `← for agents` footer and the job's name in the divider mean -- while
# `sessionId` still names the parked session behind it. The pane's own state file
# records which job took the screen, so follow it; the job's session is what the
# user means by "this session".
_claude_session_id_for_pid() {
    local ai_pid="${1:?usage: _claude_session_id_for_pid AI_PID}"
    local expect_pane="${2:-}"
    local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" entry
    # Cross-pane callers can have a different config directory from Claude.
    if [[ -d "/proc/$ai_pid" ]]; then
        config_dir="$HOME/.claude"
        while IFS= read -r -d '' entry; do
            if [[ "$entry" == CLAUDE_CONFIG_DIR=* ]]; then
                config_dir="${entry#CLAUDE_CONFIG_DIR=}"
                break
            fi
        done <"/proc/$ai_pid/environ" || return
    fi
    local state_file="$config_dir/sessions/$ai_pid.json"
    local proc_start=""

    [[ -r "$state_file" ]] || return 1
    [[ -r "/proc/$ai_pid/stat" ]] && proc_start=$(awk '{print $22}' "/proc/$ai_pid/stat" 2>/dev/null)

    python3 -c '
import json, os, sys

path, expect_pane, proc_start, jobs_dir = sys.argv[1:5]
with open(path) as handle:
    state = json.load(handle)

# "session:@window.%pane" -> "%pane"; only the pane id is stable across renames.
pane = (state.get("tmux") or "").rpartition(".")[2]
if expect_pane and pane and pane != expect_pane:
    sys.exit(1)

recorded_start = state.get("procStart")
if proc_start and recorded_start is not None and str(recorded_start) != proc_start:
    sys.exit(1)

# The pane parked on a background job: fork the job, which is what is on screen.
# A missing job record means we cannot tell what the pane is showing, so report
# nothing rather than hand back the parked session.
job_id = state.get("parkedJobId")
if job_id:
    with open(os.path.join(jobs_dir, job_id, "state.json")) as handle:
        job = json.load(handle)
    session_id = job.get("resumeSessionId") or job.get("sessionId") or ""
else:
    session_id = state.get("sessionId") or ""

if not session_id:
    sys.exit(1)

print(session_id)
' "$state_file" "$expect_pane" "$proc_start" "$config_dir/jobs"
}
