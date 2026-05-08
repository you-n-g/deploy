#!/usr/bin/env bash

set -eu

tmux set-option -g @status-window-second-line-reserve auto
tmux set-option -g @status-non-window-fixed-right-width 58
tmux set-option -g @status-buttons-expanded 0

button_light='colour244'
button_dark='colour242'
button_fg='colour235'

button() {
  range="$1"
  bg="$2"
  label="$3"
  printf '#[range=user|%s]#[bg=%s,fg=%s]%s#[norange default]' "$range" "$bg" "$button_fg" "$label"
}

compact_buttons="$(
  button sb_g "$button_light" ' g '
  button sb_cg "$button_dark" 'C-g'
  button sb_ml "$button_light" 'M-l'
  button sb_cc "$button_dark" 'C-c'
  button sb_more "$button_light" '>>>'
)"
expanded_buttons="$(
  button sb_g "$button_light" ' g '
  button sb_cg "$button_dark" 'C-g'
  button sb_t "$button_light" ' t '
  button sb_ct "$button_dark" 'C-t'
  button sb_mf "$button_light" 'M-f'
  button sb_ml "$button_dark" 'M-l'
  button sb_cc "$button_light" 'C-c'
  button sb_less "$button_dark" '<<<'
)"
tmux set-option -g @status-buttons-compact "$compact_buttons"
tmux set-option -g @status-buttons-full "$expanded_buttons"
left_buttons="#{?#{==:#{@status-buttons-expanded},1},#{@status-buttons-full},#{@status-buttons-compact}}"
window_format='#[list=on align=left]#{W:#[range=window|#{window_index}]#[bg=#{?#{==:#{e|%:#{window_index},2},0},colour214,colour220}]#[fg=colour235]#I:#W#{window_flags}#[norange list=on default],#[range=window|#{window_index} list=focus]#[bg=colour196]#[fg=colour231]#[bold]#I:#W#{window_flags}#[norange list=on default]}'

tmux set-option -g status-format[1] "#[align=left]${left_buttons}#[default]${window_format}"
