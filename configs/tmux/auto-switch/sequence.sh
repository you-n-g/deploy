#!/usr/bin/env bash
set -euo pipefail

source "$HOME/deploy/configs/tmux/ai/lib.sh"
source "$HOME/deploy/configs/tmux/script/ai_label.sh"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
sequence_edit_helper="$script_dir/sequence_edit.py"

usage() {
  cat >&2 <<'USAGE'
Usage:
  sequence.sh reset-current <pane>
  sequence.sh append-current <pane>
  sequence.sh edit [focus-pane]
  sequence.sh show

Manage the auto-switch pane sequence stored in @auto_switch_ranked_panes.
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift

ranked_option="@auto_switch_ranked_panes"
target_pane=""
edit_focus_target=""
message=""

case "$command_name" in
  reset-current|append-current)
    target_pane="${1:-}"
    [[ -n "$target_pane" ]] || { echo "$command_name requires a pane target" >&2; exit 2; }
    shift
    ;;
  edit)
    edit_focus_target="${1:-}"
    [[ -z "$edit_focus_target" ]] || shift
    ;;
  show)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage
    exit 2
    ;;
esac

[[ $# -eq 0 ]] || { echo "Unknown argument: $1" >&2; usage; exit 2; }

resolve_pane() {
  tmux display-message -p -t "$1" '#{pane_id}' 2>/dev/null
}

require_ai_pane() {
  local pane="$1" pane_pid pane_target pane_command

  pane_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] || { echo "pane does not resolve: $pane" >&2; exit 1; }
  _has_ai_proc "$pane_pid" && return 0

  pane_target="$(tmux display-message -p -t "$pane" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
  pane_command="$(tmux display-message -p -t "$pane" '#{pane_current_command}' 2>/dev/null || true)"
  {
    echo "pane is not a live local AI pane: ${pane_target:-$pane} ($pane)"
    echo "current command: ${pane_command:-unknown}"
    echo "prefix + M-a only appends panes whose local process tree contains codex, claude, or gemini; SSH/shell panes are not added directly."
  } >&2
  exit 1
}

normalize_existing_sequence() {
  python3 "$sequence_edit_helper" normalize "$1"
}

editable_sequence() {
  normalize_existing_sequence "$1"
}

status_prefix() {
  local unread="$1" running="$2" background="$3" pending="$4"
  if [[ "$pending" == "1" ]]; then
    printf '⏸ '
  elif [[ "$background" == "1" ]]; then
    printf '◒ '
  elif [[ "$running" == "1" ]]; then
    printf '● '
  elif [[ "$unread" == "1" ]]; then
    printf '◉ '
  else
    printf '○ '
  fi
}

pane_label() {
  local pane="$1"
  local session_name window_name unread running background pending attribute clean_attribute label

  session_name="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null || true)"
  window_name="$(tmux display-message -p -t "$pane" '#{window_name}' 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane" @ai_agent_unread 2>/dev/null || true)"
  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane" @ai_agent_background 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane" @ai_agent_pending 2>/dev/null || true)"
  attribute="$(tmux show -pv -t "$pane" @ai_agent_attribute 2>/dev/null || true)"
  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"
  label="${label} [${session_name}:$(_strip_ai_window_state_prefix "$window_name")]"
  printf '%s%s' "$(status_prefix "$unread" "$running" "$background" "$pending")" "$label"
}

state_label() {
  local unread="$1" running="$2" background="$3" pending="$4"

  if [[ "$pending" == "1" ]]; then
    printf 'pending'
  elif [[ "$background" == "1" ]]; then
    printf 'background'
  elif [[ "$running" == "1" ]]; then
    printf 'running'
  elif [[ "$unread" == "1" ]]; then
    printf 'unread'
  else
    printf 'idle'
  fi
}

pane_line_in_edit_file() {
  local file="$1" pane="$2"

  awk -v pane="$pane" '$1 == pane { print NR; exit }' "$file"
}

first_edit_pane_line() {
  local file="$1" ranked="$2" pane line

  for pane in $ranked; do
    line="$(pane_line_in_edit_file "$file" "$pane")"
    if [[ -n "$line" ]]; then
      printf '%s\n' "$line"
      return 0
    fi
  done

  printf '1\n'
}

edit_focus_line() {
  local file="$1" ranked="$2" focus_target="$3" focus_pane focus_window pane pane_window line

  [[ -n "$focus_target" ]] || { first_edit_pane_line "$file" "$ranked"; return 0; }
  focus_pane="$(resolve_pane "$focus_target" || true)"
  [[ -n "$focus_pane" ]] || { first_edit_pane_line "$file" "$ranked"; return 0; }

  line="$(pane_line_in_edit_file "$file" "$focus_pane")"
  [[ -z "$line" ]] || { printf '%s\n' "$line"; return 0; }

  focus_window="$(tmux display-message -p -t "$focus_pane" '#{window_id}' 2>/dev/null || true)"
  [[ -n "$focus_window" ]] || { first_edit_pane_line "$file" "$ranked"; return 0; }

  for pane in $ranked; do
    pane_window="$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null || true)"
    if [[ "$pane_window" == "$focus_window" ]]; then
      line="$(pane_line_in_edit_file "$file" "$pane")"
      [[ -z "$line" ]] || { printf '%s\n' "$line"; return 0; }
    fi
  done

  first_edit_pane_line "$file" "$ranked"
}

write_edit_file() {
  local file="$1" ranked="$2"
  python3 "$sequence_edit_helper" write "$ranked" "$file"
}

apply_edit_file() {
  local file="$1"
  python3 "$sequence_edit_helper" apply "$file"
}

switch_to_pane() {
  local pane="${1:?usage: switch_to_pane PANE}"
  local session window_id pane_id

  pane_id="$(tmux display-message -p -t "$pane" '#{pane_id}' 2>/dev/null)" || { echo "pane does not resolve: $pane" >&2; return 1; }
  session="$(tmux display-message -p -t "$pane_id" '#{session_name}')" || return 1
  window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')" || return 1

  tmux switch-client -t "$session:"
  tmux select-window -t "$window_id"
  tmux select-pane -t "$pane_id"
}

wait_after_error() {
  printf '\nPress Enter to close...'
  read -r _ || true
}

edit_sequence() {
  local tmp selected_file vim_script vim_selected_file vim_script_file editor editor_name focus_line selected_pane resolved_selected_pane
  local -a editor_argv

  tmp="$(mktemp "${TMPDIR:-/tmp}/auto-switch-sequence.XXXXXX")"
  selected_file="$(mktemp "${TMPDIR:-/tmp}/auto-switch-selected.XXXXXX")"
  vim_script="$(mktemp "${TMPDIR:-/tmp}/auto-switch-edit.XXXXXX.vim")"
  trap 'rm -f "$tmp" "$selected_file" "$vim_script"' RETURN

  ranked="$(editable_sequence "$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)")"
  [[ -n "$ranked" ]] || { echo "no live AI panes to edit" >&2; wait_after_error; return 1; }
  write_edit_file "$tmp" "$ranked"
  focus_line="$(edit_focus_line "$tmp" "$ranked" "$edit_focus_target")"
  vim_selected_file="${selected_file//\'/''}"
  cat > "$vim_script" <<VIM
setlocal filetype=conf nowrap
syntax match AutoSwitchSeparator /|/ containedin=ALL
highlight AutoSwitchSeparator ctermfg=45 cterm=bold guifg=#00d7ff gui=bold
highlight AutoSwitchStateRunning ctermfg=110 cterm=NONE guifg=#87afd7 gui=NONE
highlight AutoSwitchStateBackground ctermfg=109 cterm=NONE guifg=#87afaf gui=NONE
highlight AutoSwitchStatePending ctermfg=139 cterm=NONE guifg=#af87af gui=NONE
highlight AutoSwitchStateUnread ctermfg=143 cterm=NONE guifg=#afaf5f gui=NONE
highlight AutoSwitchStateIdle ctermfg=245 cterm=NONE guifg=#8a8a8a gui=NONE
call matchadd('AutoSwitchStateRunning', '|\\s*\\zsrunning\\ze\\s*|', 40)
call matchadd('AutoSwitchStateBackground', '|\\s*\\zsbackground\\ze\\s*|', 40)
call matchadd('AutoSwitchStatePending', '|\\s*\\zspending\\ze\\s*|', 40)
call matchadd('AutoSwitchStateUnread', '|\\s*\\zsunread\\ze\\s*|', 40)
call matchadd('AutoSwitchStateIdle', '|\\s*\\zsidle\\ze\\s*|', 40)
nnoremap <buffer> q :wq<CR>
let g:auto_switch_selected_pane_file = '$vim_selected_file'
function! AutoSwitchSaveSelectPane() abort
  let l:pane = matchstr(getline('.'), '^\\s*\\zs%[0-9]\\+\\ze\\>')
  if empty(l:pane)
    echohl ErrorMsg
    echo 'No pane id on current line'
    echohl None
    return
  endif
  call writefile([l:pane], g:auto_switch_selected_pane_file)
  write
  quit
endfunction
nnoremap <buffer> <CR> :call AutoSwitchSaveSelectPane()<CR>
VIM
  vim_script_file="${vim_script//\'/''}"

  editor="${VISUAL:-${EDITOR:-vim}}"
  read -r -a editor_argv <<< "$editor"
  editor_name="${editor_argv[0]##*/}"
  if [[ "$editor_name" == "vim" || "$editor_name" == "nvim" ]]; then
    editor_argv=("${editor_argv[0]}" -u NONE -U NONE -N -i NONE "${editor_argv[@]:1}")
    if [[ -n "$focus_line" ]]; then
      editor_argv+=(-c "call cursor(${focus_line}, 1)")
    fi
    editor_argv+=(
      -c 'syntax enable'
      -c "execute 'source' fnameescape('$vim_script_file')"
    )
  fi
  if ! "${editor_argv[@]}" "$tmp"; then
    echo "editor failed: $editor" >&2
    wait_after_error
    return 1
  fi

  if ! ranked="$(apply_edit_file "$tmp")"; then
    wait_after_error
    return 1
  fi

  tmux set-option -gq "$ranked_option" "$ranked"

  selected_pane="$(cat "$selected_file" 2>/dev/null || true)"
  if [[ -n "$selected_pane" ]]; then
    resolved_selected_pane="$(resolve_pane "$selected_pane" || true)"
    [[ -n "$resolved_selected_pane" ]] || { echo "selected pane does not resolve: $selected_pane" >&2; wait_after_error; return 1; }
    case " $ranked " in
      *" $resolved_selected_pane "*) ;;
      *) echo "selected pane is not in edited sequence: $resolved_selected_pane" >&2; wait_after_error; return 1 ;;
    esac
    switch_to_pane "$resolved_selected_pane"
  fi
}

format_sequence() {
  local ranked="$1" pane label out="" index=0
  for pane in $ranked; do
    [[ -n "$(resolve_pane "$pane" || true)" ]] || continue
    index=$((index + 1))
    label="$(pane_label "$pane")"
    out="${out:+$out | }${index}:${label}"
  done
  printf '%s\n' "${out:-empty}"
}

sequence_count() {
  local ranked="$1" pane count=0
  for pane in $ranked; do
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

case "$command_name" in
  reset-current)
    target_pane="$(resolve_pane "$target_pane")" || { echo "pane does not resolve: $target_pane" >&2; exit 1; }
    require_ai_pane "$target_pane"
    ranked="$target_pane"
    tmux set-option -gq "$ranked_option" "$ranked"
    ;;
  append-current)
    target_pane="$(resolve_pane "$target_pane")" || { echo "pane does not resolve: $target_pane" >&2; exit 1; }
    require_ai_pane "$target_pane"
    ranked="$(normalize_existing_sequence "$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)")"
    case " $ranked " in
      *" $target_pane "*) ;;
      *) ranked="${ranked:+$ranked }$target_pane" ;;
    esac
    tmux set-option -gq "$ranked_option" "$ranked"
    ;;
  edit)
    edit_sequence
    ;;
  show)
    ranked="$(normalize_existing_sequence "$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)")"
    tmux set-option -gq "$ranked_option" "$ranked"
    ;;
esac

if [[ "$command_name" == "edit" ]]; then
  exit 0
fi

if [[ -z "$message" ]]; then
  message="auto-switch sequence: $(format_sequence "$ranked")"
fi
tmux display-message "$message"
