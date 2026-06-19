#!/usr/bin/env bash

set -eu

tmux set-option -g @status-window-second-line-reserve auto
tmux set-option -g @status-non-window-fixed-right-width 61
tmux set-option -g @status-ai-window-summary-count 6
if [ -z "$(tmux show-options -gqv @tmuxg-show-orchestrator 2>/dev/null)" ]; then
  tmux set-option -g @tmuxg-show-orchestrator 1
fi
if [ -z "$(tmux show-options -gqv @status-buttons-expanded 2>/dev/null)" ]; then
  tmux set-option -g @status-buttons-expanded 0
fi
tmux list-sessions -F '#S' 2>/dev/null | while IFS= read -r session_name; do
  tmux set-option -qu -t "${session_name}:" @status-buttons-expanded 2>/dev/null || true
done
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
pending_badge="#{?#{!=:#{@ai_agent_pending},},#[nounderscore]#[fg=colour201]#[bold] ⏸#[nobold]#[underscore],}"

button() {
  range="$1"
  bg="$2"
  label="$3"
  printf '#[range=user|%s]#[bg=%s,fg=%s]%s#[norange default]' "$range" "$bg" "$button_fg" "$label"
}

button_row() {
  index=0
  while [ "$#" -gt 0 ]; do
    range="$1"
    label="$2"
    if [ $((index % 2)) -eq 0 ]; then
      bg="$button_light"
    else
      bg="$button_dark"
    fi

    button "$range" "$bg" "$label"
    index=$((index + 1))
    shift 2
  done
}

click_only() {
  printf '#[underscore]%s#[nounderscore]' "$1"
}

compact_buttons="$(
  button_row \
    sb_g ' g ' \
    sb_cg 'C-g' \
    sb_G ' G ' \
    sb_a ' a ' \
    sb_mA 'M-A' \
    sb_as 'C-m' \
    sb_mc 'M-c' \
    sb_ml 'M-l' \
    sb_cc 'C-c' \
    sb_d "$(click_only ' D ')" \
    sb_n "$(click_only ' N ')" \
    sb_more "$(click_only '>>>')"
)"
expanded_buttons="$(
  button_row \
    sb_g ' g ' \
    sb_cg 'C-g' \
    sb_G ' G ' \
    sb_a ' a ' \
    sb_mA 'M-A' \
    sb_as 'C-m' \
    sb_mc 'M-c' \
    sb_ml 'M-l' \
    sb_cc 'C-c' \
    sb_d "$(click_only ' D ')" \
    sb_n "$(click_only ' N ')" \
    sb_k ' k ' \
    sb_l ' l ' \
    sb_s "$(click_only ' S ')" \
    sb_pd 'M-p' \
    sb_p70 "$(click_only '#{?#{==:#{@pane_focus_percent},80},80*,#{?#{||:#{==:#{@pane_focus_percent},70},#{==:#{@pane_focus_70},1}},70*,70%}}')" \
    sb_t ' t ' \
    sb_ct 'C-t' \
    sb_kp "$(click_only 'K-p')" \
    sb_ks "$(click_only 'K-s')" \
    sb_mf 'M-f' \
    sb_less "$(click_only '<<<')"
)"
tmux set-option -g @status-buttons-compact "$compact_buttons"
tmux set-option -g @status-buttons-full "$expanded_buttons"
left_buttons="#{?#{==:#{@status-buttons-expanded},1},#{E:@status-buttons-full},#{E:@status-buttons-compact}}"
window_format="#[list=on align=left]#{W:#[range=window|#{window_index}]#[bg=#{?#{==:#{e|m:#{window_index},2},0},${window_bg_even},${window_bg_odd}}]#[fg=#{?#{==:#{e|m:#{window_index},2},0},${window_fg_even},${window_fg_odd}}]#[bold]#I#[nobold]#[underscore]#W${pending_badge}#[fg=#{?#{==:#{e|m:#{window_index},2},0},${window_fg_even},${window_fg_odd}}]#{window_flags}#[nounderscore]#[norange list=on default],#[range=window|#{window_index} list=focus]#[bg=${window_active_bg}]#[fg=${window_active_fg}]#[bold]#I#[nobold]#[underscore]#W${pending_badge}#[fg=${window_active_fg}]#{window_flags}#[nounderscore]#[norange list=on default]}"
ai_summary="#[align=left]#(${HOME}/deploy/configs/tmux/script/print_ai_window_summary.sh)"

tmux set-option -g status-format[1] "#{?#{==:#{@status-buttons-expanded},1},#[align=left]#{E:@status-buttons-full},#[align=left]${left_buttons}#[default]${window_format}}"
tmux set-option -g status-format[2] "#{?#{==:#{@status-buttons-expanded},1},#[align=left]${window_format},${ai_summary}}"
tmux set-option -g status-format[3] "$ai_summary"
