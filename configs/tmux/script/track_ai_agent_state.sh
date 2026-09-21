#!/usr/bin/env bash

set -eu

# tmux state written by this script
#
# Pane options:
# - @ai_agent_running:
#   "1" means the AI pane is currently processing a foreground turn. "0" means
#   it has stopped. This drives the busy marker in status lines and is set by
#   the running/background/idle/init states.
# - @ai_agent_background:
#   "1" means Claude/Codex has paused the foreground turn but still has
#   background work active. When set, it takes precedence over running/unread in
#   display code. The option is unset when there is no background work.
# - @ai_agent_unread:
#   "1" means the AI pane stopped while it was not visible to the user. It is
#   cleared when the user visits a live AI pane or when the pane stops while
#   already visible.
# - @ai_agent_pending:
#   Non-empty means the pane is intentionally waiting on an external condition
#   and should not be selected by auto-switch. The value is the pending reason;
#   "/" is the default user-triggered pending marker when no reason was given.
#   It is cleared when that pane starts or resumes a non-pending running turn,
#   and that transition publishes a running event for auto-switch waiters.
#   toggle-pending clears it back to idle on a second invocation.
# - @ai_agent_attribute:
#   A short generated description of the pane's current task. It is generated
#   lazily once and kept stable across later prompts until init/reset clears it.
# - @ai_agent_orchestrator_idle_notified_activity:
#   The tmux #{window_activity} value from the last idle notification sent to
#   the session's orchestrator window. It prevents sending the same idle update
#   twice for the same window activity. The running state clears it so a later
#   turn can notify again.
#
# Global options:
# - @ai_agent_event_seq:
#   Monotonic event counter incremented by emit_ai_agent_event. Watchers can use
#   it to notice that a new running/pending event was published.
# - @ai_agent_event_pane:
#   Pane id, such as %12, for the most recent published AI-agent event.
# - @ai_agent_event_state:
#   Event state name for the most recent published event, currently running or
#   pending.
# - @ai_agent_event_time:
#   Unix timestamp for the most recent published event.
# - @ai_agent_event_source:
#   Optional event source from AI_AGENT_STATE_SOURCE, such as a Codex hook or a
#   supplemental tracker. Empty when the caller did not identify itself.
# - @ai_agent_event_client_pane:
#   Best-effort pane id for the user's most recently active non-readonly,
#   non-control tmux client when the event was published.
#
# tmux formats read by this script:
# - #{pane_id}: stable pane id used as the canonical pane target.
# - #{window_id}: stable window id used for visibility checks.
# - #{session_name}: current session name, used to find a same-session
#   orchestrator.
# - #{window_index} / #{pane_index}: user-facing target numbers used in
#   notification text and logs.
# - #{window_name} / #W: current tmux window name.
# - #{window_activity}: tmux's last activity timestamp for the window.
# - #{window_active}: whether the window is active in its session.
# - #{session_attached}: whether the session has an attached client.
# - #{pane_current_command}: command currently shown by tmux for the pane.
# - #{pane_pid}: root process id for the pane, used to detect live AI processes.
# - #{client_name}, #{client_readonly}, #{client_control_mode}, #{client_activity}:
#   client metadata used to find the likely current user pane for event records.
#
# Environment:
# - AI_AGENT_STATE_LOG:
#   Optional path for debug logs. If unset, logs go to
#   ~/.cache/tmux-ai-agent-state.log.
# - AI_AGENT_PROMPT:
#   The text the user or another agent submitted, set by the UserPromptSubmit
#   hooks of both agents. Non-empty means this invocation starts a turn with a
#   known prompt, and log_ai_agent_prompt records it. No other caller sets it.
# - AI_AGENT_PROMPT_LOG:
#   Optional path for the prompt log. If unset, rows go to
#   ~/.cache/tmux-ai-prompts.jsonl.

state="${1:?usage: track_ai_agent_state.sh init|running|background|idle|visit|unread|pending|toggle-pending TARGET [PENDING_REASON]}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

target="${2:-${TMUX_PANE:?usage: track_ai_agent_state.sh init|running|background|idle|visit|unread|pending|toggle-pending TARGET [PENDING_REASON]}}"
if ! pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')" || [ -z "$pane_id" ]; then
  if [ "$state" = "visit" ]; then
    exit 0
  fi
  exit 1
fi

# Not an AI window, so it gets no AI state: no marker and no place in
# any list. The states that go through is_live_ai_pane below would catch this
# too, but init/running/background/idle do not, and those are exactly the ones a
# brokered session fires. See _pane_hosts_ai_service.
if _pane_hosts_ai_service "$(tmux display-message -p -t "$pane_id" '#{pane_pid}')"; then
  exit 0
fi

window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"
state_source="${AI_AGENT_STATE_SOURCE:-}"
pending_reason="${AI_AGENT_PENDING_REASON:-}"
if [ "$state" = "pending" ] || [ "$state" = "toggle-pending" ]; then
  if [ -z "$pending_reason" ]; then
    if [ "$#" -ge 3 ]; then
      pending_reason="${*:3}"
    else
      pending_reason="/"
    fi
  fi
  [ -n "$pending_reason" ] || pending_reason="/"
fi

log_ai_agent_state() {
  local log_file log_dir ts pane_target window_name window_activity window_active
  local running background unread pending notified_activity pane_command pane_pid
  local source_part

  log_file="${AI_AGENT_STATE_LOG:-$HOME/.cache/tmux-ai-agent-state.log}"
  log_dir="$(dirname "$log_file")"
  mkdir -p "$log_dir"

  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  pane_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}.#{pane_index}')"
  window_name="$(tmux display-message -p -t "$window_id" '#W')"
  window_activity="$(tmux display-message -p -t "$pane_id" '#{window_activity}')"
  window_active="$(tmux display-message -p -t "$window_id" '#{window_active}')"
  pane_command="$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')"
  pane_pid="$(tmux display-message -p -t "$pane_id" '#{pane_pid}')"
  running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane_id" @ai_agent_background 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
  notified_activity="$(tmux show -pv -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity 2>/dev/null || true)"

  source_part=""
  if [ -n "$state_source" ]; then
    printf -v source_part ' source=%q' "$state_source"
  fi
  printf '%s%s state=%s pane=%s window_id=%s window_name=%q activity=%s active=%s command=%q pid=%s running=%q background=%q unread=%q pending=%q notified_activity=%q\n' \
    "$ts" "$source_part" "$state" "$pane_target" "$window_id" "$window_name" "$window_activity" "$window_active" "$pane_command" "$pane_pid" \
    "$running" "$background" "$unread" "$pending" "$notified_activity" >> "$log_file"
}

trim_spaces() {
  local text="$1"

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

# Records the prompt that started this turn, tagged with who sent it.
#
# tmux scrollback rolls off, so this file is the only durable record of what a
# pane was actually asked -- including the messages agents send each other that
# never reach the sender's .tma/msg.md, and the ones the user types, which that
# file deliberately leaves out.
#
# Rows are appended as JSON lines under a lock: a prompt is easily longer than
# the size a write stays atomic at, and several panes can be submitted at once.
#
# A TMA message carries a "⟦TMA⟧ sender → recipient" line. It is normally the
# first line, but a message whose body is a slash command puts it last, because
# a leading signature would keep the TUI from recognising the command. Both
# ends are checked; a prompt with neither is the user typing.
log_ai_agent_prompt() {
  local log_file log_dir ts window_name
  local first_line last_line signature rest sender from to row

  [ -n "${AI_AGENT_PROMPT:-}" ] || return 0

  sender="user"
  from=""
  to=""
  first_line="${AI_AGENT_PROMPT%%$'\n'*}"
  last_line="${AI_AGENT_PROMPT##*$'\n'}"
  for signature in "$first_line" "$last_line"; do
    case "$signature" in
      '⟦TMA⟧'*)
        sender="tma"
        rest="${signature#⟦TMA⟧}"
        # An arrow is what makes the line a routable signature. Without one the
        # row still says tma, but there is nothing to split into from/to.
        case "$rest" in
          *→*)
            from="$(trim_spaces "${rest%%→*}")"
            to="$(trim_spaces "${rest#*→}")"
            ;;
        esac
        break
        ;;
    esac
  done

  log_file="${AI_AGENT_PROMPT_LOG:-$HOME/.cache/tmux-ai-prompts.jsonl}"
  log_dir="$(dirname "$log_file")"
  mkdir -p "$log_dir"

  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  window_name="$(tmux display-message -p -t "$window_id" '#W')"
  row="$(jq -cn \
    --arg time "$ts" \
    --arg pane "$pane_id" \
    --arg window "$window_name" \
    --arg sender "$sender" \
    --arg from "$from" \
    --arg to "$to" \
    --arg prompt "$AI_AGENT_PROMPT" \
    '{time: $time, pane: $pane, window: $window, sender: $sender}
      + (if $from == "" then {} else {from: $from} end)
      + (if $to == "" then {} else {to: $to} end)
      + {prompt: $prompt}')"

  { flock 9; printf '%s\n' "$row" >&9; } 9>>"$log_file"
}

ensure_ai_agent_attribute() {
  if [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]; then
    return
  fi

  local cmd
  printf -v cmd '%q %q' "$SCRIPT_DIR/generate_ai_window_attribute.sh" "$pane_id"
  tmux run-shell -b "$cmd"
}

has_ai_agent_state() {
  [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_background 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]
}

is_live_ai_pane() {
  local pane_pid

  pane_pid="$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null || true)"
  [ -n "$pane_pid" ] || return 1
  _has_ai_proc "$pane_pid"
}

is_window_visible() {
  [ "$(tmux display-message -p -t "$window_id" '#{window_active}')" = "1" ] \
    && [ "$(tmux display-message -p -t "$window_id" '#{session_attached}')" != "0" ]
}

current_user_pane() {
  local client client_readonly control_mode pane activity best_pane best_activity

  best_pane=""
  best_activity=-1

  while IFS='	' read -r client client_readonly control_mode pane activity; do
    [ -n "$client" ] || continue
    if [ "$client_readonly" = "1" ] || [ "$control_mode" = "1" ]; then
      continue
    fi
    [ -n "$pane" ] || continue
    case "$activity" in
      ""|*[!0-9]*) activity=0 ;;
    esac
    if [ "$activity" -gt "$best_activity" ]; then
      best_activity="$activity"
      best_pane="$pane"
    fi
  done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}	#{pane_id}	#{client_activity}' 2>/dev/null || true)

  [ -n "$best_pane" ] || return 1
  printf '%s\n' "$best_pane"
}

emit_ai_agent_event() {
  local event_state="$1" seq event_time client_pane

  # Publish a small event record for auto-switch waiters.
  # "User" here means the interactive tmux client pane that was most recently
  # active among non-readonly, non-control clients, not the Unix account name.
  # wait-submit.sh only treats the event as a submitted user action when
  # @ai_agent_event_pane matches @ai_agent_event_client_pane.
  seq="$(tmux show-option -gqv @ai_agent_event_seq 2>/dev/null || true)"
  case "$seq" in
    ""|*[!0-9]*) seq=0 ;;
  esac
  seq=$((seq + 1))
  event_time="$(date +%s)"
  client_pane="$(current_user_pane || true)"

  tmux set-option -gq @ai_agent_event_seq "$seq"
  tmux set-option -gq @ai_agent_event_pane "$pane_id"
  tmux set-option -gq @ai_agent_event_state "$event_state"
  tmux set-option -gq @ai_agent_event_time "$event_time"
  tmux set-option -gq @ai_agent_event_source "$state_source"
  tmux set-option -gq @ai_agent_event_client_pane "$client_pane"
  tmux wait-for -S ai-agent-state 2>/dev/null || true
}

is_tui_idle_notify_source() {
  case "$state_source" in
    tui-output:busy-to-idle|tui-output:stale-running-idle) return 0 ;;
    *) return 1 ;;
  esac
}

has_pending_watch_target_wakeup() {
  local pid command

  while read -r pid command; do
    [ -n "$pid" ] || continue
    case "$command" in
      bash\ */run-wakeup.sh*|*/bash\ */run-wakeup.sh*) ;;
      *) continue ;;
    esac
    case " $command " in
      *" --pane $pane_id "*) return 0 ;;
    esac
  # -ww: Claude Code runs hooks with COLUMNS set to the pane width, and ps
  # truncates command lines to COLUMNS even when piped. The --pane argument
  # sits ~200 chars in, so without -ww a 124-column pane never matches.
  done < <(ps -axwwo pid=,command=)

  return 1
}

# 一个 TMA 停下来之后 orchestrator 该做什么，是随项目变的：这个 repo 要更新
# mindmap，那个 repo 可能要跑测试或者回写某个看板。所以项目可以在
# .tma/idle-notify.md 里写一段，追加到下面那条通用提示后面。
# 从 orchestrator pane 的 cwd 往上找到 git root，第一个命中的生效，不合并。
# 用 --show-prefix 而不是 --show-toplevel：cwd 经常是通过 symlink 进 repo 的，
# toplevel 给的是物理路径，拿来做字符串比较永远对不上。
project_idle_note() {
  local dir="$1" prefix levels note i

  [ -d "$dir" ] || return 0
  prefix="$(git -C "$dir" rev-parse --show-prefix 2>/dev/null || true)"
  levels="$(printf '%s' "$prefix" | tr -cd / | wc -c)"
  for (( i = 0; i <= levels; i++ )); do
    note="$dir/.tma/idle-notify.md"
    # 压成单行，理由同下面 prompt_text 处：paste-buffer 没开 -p。
    if [ -f "$note" ]; then
      tr '\n' ' ' < "$note" | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//'
      return 0
    fi
    dir="$(dirname "$dir")"
  done
}

# Paste a message into a TUI pane and make sure it actually got submitted.
#
# The wait between paste and Enter is not a formality, and 0.2s was not enough:
# a Codex/Claude TUI still digesting a few hundred characters of paste swallows
# the Enter, and the message just sits in the input box. Four idle notices piled
# up unsent in one orchestrator that way. CLAUDE.md and watch-target/SKILL.md
# both specify a full second; this is the same submit-then-verify shape
# watch-target/scripts/run-wakeup.sh already uses.
#
# Serialized per target pane. Waiting longer widens the window in which another
# pane's paste can land between ours and our Enter -- several agents going idle
# together is exactly the case that surfaced this -- and interleaved pastes
# submit as one merged blob. The lock makes the longer wait safe.
submit_to_tui_pane() {
  local pane="$1" text="$2" buffer="$3"
  local lock_file="$HOME/.cache/tma-notify-${pane#%}.lock"

  mkdir -p "$HOME/.cache"
  (
    flock 9
    tmux set-buffer -b "$buffer" "$text"
    tmux paste-buffer -b "$buffer" -t "$pane"
    sleep 2
    tmux send-keys -t "$pane" Enter
    sleep 2
    # Retry once regardless of @ai_agent_running. A busy TUI was already marked
    # running before submission, so that option cannot prove the first Enter
    # landed. If it did land, the composer is empty and this Enter is harmless.
    tmux send-keys -t "$pane" Enter
    tmux delete-buffer -b "$buffer" 2>/dev/null || true
  ) 9>"$lock_file"
}

notify_orchestrator_on_idle() {
  local session_name pane_target source_window_name orchestrator_window_id orchestrator_pane_id
  local prompt_text project_note buffer_name activity notified_activity

  # Only supplemental TUI-observed idle edges should ask the orchestrator to
  # summarize an idle pane. Normal Stop hooks still own state updates; the TUI
  # path only covers transitions those hooks cannot see.
  is_tui_idle_notify_source || return 0

  session_name="$(tmux display-message -p -t "$pane_id" '#{session_name}')"
  pane_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}.#{pane_index}')"
  source_window_name="$(tmux display-message -p -t "$window_id" '#W')"
  activity="$(tmux display-message -p -t "$pane_id" '#{window_activity}')"
  notified_activity="$(tmux show -pv -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity 2>/dev/null || true)"

  [ "$source_window_name" != "orchestrator" ] || return 0
  [ "$activity" != "$notified_activity" ] || return 0

  orchestrator_window_id=""
  while IFS='	' read -r window_row_id window_row_name; do
    [ -n "$window_row_id" ] || continue
    if [ "$window_row_name" = "orchestrator" ]; then
      orchestrator_window_id="$window_row_id"
      break
    fi
  done < <(tmux list-windows -t "$session_name" -F '#{window_id}	#{window_name}' 2>/dev/null || true)

  [ -n "$orchestrator_window_id" ] || return 0

  orchestrator_pane_id="$(_find_ai_pane_in_window "$orchestrator_window_id" 2>/dev/null || true)"
  [ -n "$orchestrator_pane_id" ] || return 0
  [ "$orchestrator_pane_id" != "$pane_id" ] || return 0

  # 这条 idle 边可能来自「turn 正常结束」，也可能来自「上游 LLM-API 把流掐了」。
  # 后者 Claude Code 不会自动重试（流已经产出过内容，重试会重复执行 tool call），
  # Stop hook 也不触发，于是一个本来还要继续干活的 TMA 就永久停在半路。让
  # orchestrator 先分辨是哪一种，是后者就替它续上。
  # 保持单行：paste-buffer 没开 -p，多行文本会把换行直接送进 TUI。
  prompt_text="请关注这个 TMA：${pane_target}（${source_window_name}）已经停下来并有新的更新。根据 project-mindmap 这个skill看是否需要汇总信息。另外先 capture 这个 pane 确认它是怎么停下来的：如果是被上游 LLM-API 错误打断的（屏幕上有 API Error / Connection lost mid-response / 连接重置 / 请求超时这类，也就是上游不出错它就会继续干下去），那它并没有把活做完，请直接向它发送「继续」让它接着原来的工作，不要按任务已完成来汇总。"
  project_note="$(project_idle_note "$(tmux display-message -p -t "$orchestrator_pane_id" '#{pane_current_path}')")"
  [ -z "$project_note" ] || prompt_text="$prompt_text $project_note"
  buffer_name="tma-idle-notify-${pane_id#%}"
  submit_to_tui_pane "$orchestrator_pane_id" "$prompt_text" "$buffer_name"
  tmux set-option -pq -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity "$activity"
}

log_ai_agent_state
log_ai_agent_prompt

case "$state" in
  init)
    # Codex/Claude SessionStart can fire for resume/compact/status-bridge style
    # events inside a still-running tmux pane. Keep the existing attribute stable;
    # users can reset it explicitly from the AI pane picker when it is stale.
    #
    # Clearing @ai_agent_running here assumes the pane really is between turns.
    # Auto-compaction breaks that assumption: it fires mid-turn and the turn
    # keeps going afterwards, but @ai_agent_running only comes back on the next
    # UserPromptSubmit, which never arrives. So the Claude hook config no longer
    # routes the compact source here; a turn that dies without a Stop hook is
    # cleaned up by the stale-running timeout in state-tracker/tui-output.sh.
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
    ;;
  running)
    was_running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
    was_pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
    tmux set-option -pq -t "$pane_id" @ai_agent_running 1
    tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
    tmux set-option -pqu -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity 2>/dev/null || true
    # User preference: generate a pane attribute only once and keep it stable
    # across later prompts. Do not reset it on UserPromptSubmit.
    ensure_ai_agent_attribute
    if [ "$was_running" != "1" ] || [ -n "$was_pending" ]; then
      tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
      emit_ai_agent_event running
    fi
    if is_window_visible; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    fi
    ;;
  background)
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pq -t "$pane_id" @ai_agent_background 1
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
    ;;
  idle)
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    if has_pending_watch_target_wakeup; then
      # The foreground turn stopped only because watch-target is waiting for
      # its next one-shot wakeup. Keep the pane in background until that
      # wakeup submits the next turn.
      tmux set-option -pq -t "$pane_id" @ai_agent_background 1
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
      tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
    else
      tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
      if is_window_visible; then
        tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
      else
        tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
      fi
      ensure_ai_agent_attribute
      notify_orchestrator_on_idle
    fi
    ;;
  visit)
    if is_live_ai_pane; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      if has_ai_agent_state; then
        _clear_ai_pane_state "$pane_id"
      fi
    fi
    ;;
  unread)
    if is_live_ai_pane; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    else
      if has_ai_agent_state; then
        _clear_ai_pane_state "$pane_id"
      fi
    fi
    ;;
  pending|toggle-pending)
    was_running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
    was_pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    if [ "$state" = "toggle-pending" ] && [ -n "$was_pending" ]; then
      # Manual unpark returns to idle without the completion notifications
      # or submission event that would move the user away from this pane.
      tmux set-option -pqu -t "$pane_id" @ai_agent_pending
    else
      tmux set-option -pq -t "$pane_id" @ai_agent_pending "$pending_reason"
      if [ "$was_running" != "1" ] && [ -z "$was_pending" ]; then
        emit_ai_agent_event pending
      fi
    fi
    ;;
  *)
    echo "unknown AI agent state: $state" >&2
    exit 1
    ;;
esac

"$SCRIPT_DIR/refresh_status_lines.sh" "$pane_id"
