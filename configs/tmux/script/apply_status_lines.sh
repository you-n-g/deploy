#!/usr/bin/env bash

set -eu

tmux set-option -g @status-window-second-line-reserve auto
tmux set-option -g @status-non-window-fixed-right-width 58
tmux set-option -g @status-buttons-expanded 0
tmux set-option -g window-status-separator ''

button_light='colour244'
button_dark='colour242'
button_fg='colour235'
window_bg_even='colour214'
window_fg_even='colour235'
window_bg_odd='colour220'
window_fg_odd='colour235'
window_active_bg='colour196'
window_active_fg='colour231'

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
window_format="#[list=on align=left]#{W:#[range=window|#{window_index}]#[bg=#{?#{==:#{e|m:#{window_index},2},0},${window_bg_even},${window_bg_odd}}]#[fg=#{?#{==:#{e|m:#{window_index},2},0},${window_fg_even},${window_fg_odd}}]#[bold]#I#[nobold]#[underscore]#W#{window_flags}#[nounderscore]#[norange list=on default],#[range=window|#{window_index} list=focus]#[bg=${window_active_bg}]#[fg=${window_active_fg}]#[bold]#I#[nobold]#[underscore]#W#{window_flags}#[nounderscore]#[norange list=on default]}"

tmux set-option -g status-format[1] "#[align=left]${left_buttons}#[default]${window_format}"
