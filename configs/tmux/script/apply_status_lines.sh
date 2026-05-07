#!/usr/bin/env bash

set -eu

tmux set-option -g @status-window-second-line-reserve auto
tmux set-option -g @status-non-window-fixed-right-width 58

button_g='#[range=user|sb_g]#[bg=colour244,fg=colour235] g #[norange default]'
button_cg='#[range=user|sb_cg]#[bg=colour244,fg=colour235]C-g#[norange default]'
button_t='#[range=user|sb_t]#[bg=colour244,fg=colour235] t #[norange default]'
button_ct='#[range=user|sb_ct]#[bg=colour244,fg=colour235]C-t#[norange default]'
button_mf='#[range=user|sb_mf]#[bg=colour244,fg=colour235]M-f#[norange default]'
button_ml='#[range=user|sb_ml]#[bg=colour244,fg=colour235]M-l#[norange default]'
button_cc='#[range=user|sb_cc]#[bg=colour244,fg=colour235]C-c#[norange default]'
gap='#[default] '
left_buttons="${button_g}${gap}${button_cg}${gap}${button_t}${gap}${button_ct}${gap}${button_mf}${gap}${button_ml}${gap}${button_cc}${gap}"
window_format='#[list=on align=left]#{W:#[range=window|#{window_index}]#[bg=#{?#{==:#{e|%:#{window_index},2},0},colour214,colour220}]#[fg=colour235]#I:#W#{window_flags}#[norange list=on default],#[range=window|#{window_index} list=focus]#[bg=colour196]#[fg=colour231]#[bold]#I:#W#{window_flags}#[norange list=on default]}'

tmux set-option -g status-format[1] "#[align=left]${left_buttons}#[default]${window_format}"
