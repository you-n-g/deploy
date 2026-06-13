#!/usr/bin/env bash
set -euo pipefail

source "$HOME/deploy/configs/tmux/ai/lib.sh"
source "$HOME/deploy/configs/tmux/script/ai_label.sh"

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
edit_cached_panes=""
parsed_attribute_panes=""
edit_target_width=0
edit_state_width=0
edit_attribute_width=0
parsed_ranked=""

map_key_for_pane() {
  local pane="$1"
  pane="${pane//[^[:alnum:]_]/_}"
  printf '%s\n' "$pane"
}

map_set() {
  local prefix="$1" pane="$2" value="$3" key var quoted
  key="$(map_key_for_pane "$pane")"
  var="${prefix}_${key}"
  printf -v quoted '%q' "$value"
  eval "$var=$quoted"
}

map_get() {
  local prefix="$1" pane="$2" key var
  key="$(map_key_for_pane "$pane")"
  var="${prefix}_${key}"
  printf '%s' "${!var-}"
}

map_has() {
  local prefix="$1" pane="$2" key var
  key="$(map_key_for_pane "$pane")"
  var="${prefix}_${key}"
  eval "[[ \${$var+x} ]]"
}

remember_pane() {
  local pane="$1"
  case " $edit_cached_panes " in
    *" $pane "*) ;;
    *) edit_cached_panes="${edit_cached_panes:+$edit_cached_panes }$pane" ;;
  esac
}

remember_parsed_attribute_pane() {
  local pane="$1"
  case " $parsed_attribute_panes " in
    *" $pane "*) ;;
    *) parsed_attribute_panes="${parsed_attribute_panes:+$parsed_attribute_panes }$pane" ;;
  esac
}
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
  local pane="$1" pane_pid
  pane_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] || { echo "pane does not resolve: $pane" >&2; exit 1; }
  _has_ai_proc "$pane_pid" || { echo "pane is not a live AI pane: $pane" >&2; exit 1; }
}

normalize_existing_sequence() {
  local ranked="$1" candidate resolved seen="" out=""
  for candidate in $ranked; do
    resolved="$(resolve_pane "$candidate" || true)"
    [[ -n "$resolved" ]] || continue
    case " $seen " in
      *" $resolved "*) continue ;;
    esac
    seen="$seen $resolved"
    out="${out:+$out }$resolved"
  done
  printf '%s\n' "$out"
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

load_edit_pane_cache() {
  local pane window_id session_name window_name pane_index path unread running background pending attribute
  local field_sep

  field_sep=$'\037'
  while IFS="$field_sep" read -r pane window_id session_name window_name pane_index path unread running background pending attribute; do
    [[ -n "$pane" ]] || continue
    remember_pane "$pane"
    map_set edit_session "$pane" "$session_name"
    map_set edit_window_id "$pane" "$window_id"
    map_set edit_window "$pane" "$window_name"
    map_set edit_index "$pane" "$pane_index"
    map_set edit_path "$pane" "$path"
    map_set edit_unread "$pane" "$unread"
    map_set edit_running "$pane" "$running"
    map_set edit_background "$pane" "$background"
    map_set edit_pending "$pane" "$pending"
    map_set edit_attribute "$pane" "$attribute"
  done < <(tmux list-panes -a \
    -F $'#{pane_id}\037#{window_id}\037#{session_name}\037#{window_name}\037#{pane_index}\037#{pane_current_path}\037#{@ai_agent_unread}\037#{@ai_agent_running}\037#{@ai_agent_background}\037#{@ai_agent_pending}\037#{@ai_agent_attribute}')
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
  local file="$1" ranked="$2" focus_target="$3" focus_pane focus_window pane line

  [[ -n "$focus_target" ]] || { first_edit_pane_line "$file" "$ranked"; return 0; }
  focus_pane="$(resolve_pane "$focus_target" || true)"
  [[ -n "$focus_pane" ]] || { first_edit_pane_line "$file" "$ranked"; return 0; }

  line="$(pane_line_in_edit_file "$file" "$focus_pane")"
  [[ -z "$line" ]] || { printf '%s\n' "$line"; return 0; }

  focus_window="$(tmux display-message -p -t "$focus_pane" '#{window_id}' 2>/dev/null || true)"
  [[ -n "$focus_window" ]] || { first_edit_pane_line "$file" "$ranked"; return 0; }

  for pane in $ranked; do
    if [[ "$(map_get edit_window_id "$pane")" == "$focus_window" ]]; then
      line="$(pane_line_in_edit_file "$file" "$pane")"
      [[ -z "$line" ]] || { printf '%s\n' "$line"; return 0; }
    fi
  done

  first_edit_pane_line "$file" "$ranked"
}

pane_edit_comment() {
  local pane="$1"
  local session_name window_name pane_index unread running background pending path state target_label

  map_has edit_session "$pane" || { echo "pane missing from edit cache: $pane" >&2; return 1; }
  session_name="$(map_get edit_session "$pane")"
  window_name="$(map_get edit_window "$pane")"
  pane_index="$(map_get edit_index "$pane")"
  unread="$(map_get edit_unread "$pane")"
  running="$(map_get edit_running "$pane")"
  background="$(map_get edit_background "$pane")"
  pending="$(map_get edit_pending "$pane")"
  path="$(map_get edit_path "$pane")"
  state="$(state_label "$unread" "$running" "$background" "$pending")"
  window_name="$(_strip_ai_window_state_prefix "$window_name")"
  target_label="${session_name}:${window_name}.${pane_index}"

  printf '%-*s | %-*s | %s' \
    "$edit_target_width" "$target_label" \
    "$edit_state_width" "$state" \
    "$path"
}

pane_edit_attribute() {
  local pane="$1" attribute

  attribute="$(map_get edit_attribute "$pane")"
  printf '%s' "$attribute" | strip_tmux_format
}

prepare_edit_column_widths() {
  local ranked="$1" pane session_name window_name pane_index unread running background pending attribute
  local clean_attribute path state target_label

  edit_target_width=0
  edit_state_width=0
  edit_attribute_width=0

  for pane in $ranked; do
    map_has edit_session "$pane" || continue
    session_name="$(map_get edit_session "$pane")"
    window_name="$(_strip_ai_window_state_prefix "$(map_get edit_window "$pane")")"
    pane_index="$(map_get edit_index "$pane")"
    unread="$(map_get edit_unread "$pane")"
    running="$(map_get edit_running "$pane")"
    background="$(map_get edit_background "$pane")"
    pending="$(map_get edit_pending "$pane")"
    attribute="$(map_get edit_attribute "$pane")"
    clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
    clean_attribute="${clean_attribute:-no attribute}"
    state="$(state_label "$unread" "$running" "$background" "$pending")"
    target_label="${session_name}:${window_name}.${pane_index}"
    path="$(map_get edit_path "$pane")"

    [ "${#target_label}" -le "$edit_target_width" ] || edit_target_width="${#target_label}"
    [ "${#state}" -le "$edit_state_width" ] || edit_state_width="${#state}"
    [ "${#clean_attribute}" -le "$edit_attribute_width" ] || edit_attribute_width="${#clean_attribute}"
    [ -n "$path" ] || true
  done
}

write_edit_file() {
  local file="$1" ranked="$2" pane comment attribute

  load_edit_pane_cache
  prepare_edit_column_widths "$ranked"

  {
    printf '# Edit auto-switch order. Keep one pane id before "#"; edit text between pane id and "#".\n'
    printf '# Reorder lines to change priority. Delete a line to remove that pane from the sequence.\n'
    printf '# Vim shortcut: normal-mode q saves and exits.\n'
    printf '# Vim shortcut: normal-mode Enter saves, exits, and switches to the pane on the current line.\n'
    printf '# Text between pane id and "#" updates @ai_agent_attribute; leave it empty or write "no attribute" to clear.\n'
    printf '# Text after "#" is informational only. Long lines intentionally do not wrap in vim.\n\n'
    for pane in $ranked; do
      comment="$(pane_edit_comment "$pane")"
      attribute="$(pane_edit_attribute "$pane")"
      if [[ -n "$attribute" ]]; then
        printf '%s %-*s # %s\n' "$pane" "$edit_attribute_width" "$attribute" "$comment"
      else
        printf '%s # %s\n' "$pane" "$comment"
      fi
    done
  } > "$file"
}

trim_ascii() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

parse_edit_file() {
  local file="$1" line line_no=0 before_hash pane resolved seen="" out=""
  local attribute

  parsed_ranked=""
  parsed_attribute_panes=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    before_hash="${line%%#*}"
    before_hash="$(trim_ascii "$before_hash")"
    [[ -n "$before_hash" ]] || continue

    pane="${before_hash%%[[:space:]]*}"
    attribute="${before_hash#"$pane"}"
    attribute="$(trim_ascii "$attribute")"

    resolved="$(resolve_pane "$pane" || true)"
    [[ -n "$resolved" ]] || { echo "line $line_no pane does not resolve: $pane" >&2; return 1; }

    case " $seen " in
      *" $resolved "*) echo "line $line_no duplicate pane: $resolved" >&2; return 1 ;;
    esac
    seen="$seen $resolved"
    out="${out:+$out }$resolved"
    remember_parsed_attribute_pane "$resolved"
    map_set parsed_attribute "$resolved" "$attribute"
  done < "$file"

  [[ -n "$out" ]] || { echo "edited sequence is empty" >&2; return 1; }
  parsed_ranked="$out"
}

apply_edit_attributes() {
  local ranked="$1" pane attribute old_attribute new_attribute

  for pane in $ranked; do
    attribute="$(map_get parsed_attribute "$pane")"
    if [[ "$attribute" == "no attribute" ]]; then
      attribute=""
    fi

    old_attribute="$(map_get edit_attribute "$pane")"
    [[ "$old_attribute" == "$attribute" ]] && continue
    old_attribute="$(printf '%s' "$old_attribute" | strip_tmux_format)"
    new_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
    [[ "$old_attribute" == "$new_attribute" ]] || {
      if [[ -n "$new_attribute" ]]; then
        tmux set-option -pq -t "$pane" @ai_agent_attribute "$new_attribute"
      else
        tmux set-option -pqu -t "$pane" @ai_agent_attribute 2>/dev/null || true
      fi
      "$HOME/deploy/configs/tmux/script/refresh_status_lines.sh" "$pane"
    }
  done
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

  if ! parse_edit_file "$tmp"; then
    wait_after_error
    return 1
  fi

  ranked="$parsed_ranked"
  apply_edit_attributes "$ranked"
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
