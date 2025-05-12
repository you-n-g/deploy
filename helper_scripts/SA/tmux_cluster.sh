#!/bin/sh

create_panes() {
  # Usage: bash ~/deploy/helper_scripts/SA/tmux_cluster.sh create_panes {a,b,c,d}.afeyoung.icu

  # 1) we create a new tmux window for current session
  tmux new-window

  for ip in "$@" ; do
    # 2) for each ip, we create a pane with shell; and then input the ip address as a command into each pane respectively
    tmux split-window -h
    tmux send-keys "$ip"
  done

  # close the initial pane and Go back to the first pane
  tmux kill-pane -t 0

  # Go back to the first pane
  tmux select-pane -t 0
  tmux select-layout tiled
  tmux set synchronize-panes on
}


interactive_term() {
  SESSION_NAME=$1   # "your-session-name"
  WINDOW_INDEX=$2   # Index of the window in the session

  # Get the list of pane IDs in the specified window
  PANES=$(tmux list-panes -t "${SESSION_NAME}:${WINDOW_INDEX}" -F "#{pane_id}")


  echo "Enter commands to send to all panes. Type 'exit' to quit."

  while true; do
    # Use 'read -r -p' to preserve backslashes and prevent interpretation of escape characters (e.g., \" stays as \")
    read -r -p "> " INPUT  # This preserves backslashes and keeps INPUT as literally entered

    # Exit the loop if the user types 'exit'
    if [ "$INPUT" = "EXIT" ]; then
      break
    fi

    # TODO:  change it like the interactive_term_win() function;

    # Loop through each pane and send the input
    for PANE in $PANES; do
      # unsync to avoid duplicated input.
      tmux set-window-option -t "${SESSION_NAME}:${WINDOW_INDEX}" synchronize-panes off
      tmux send-keys -t "$PANE" "$INPUT" C-m
    done
  done
}

# Function: create_wins() and interactive_term_win() for window-based operations
create_wins() {
  # Usage: bash ~/deploy/helper_scripts/SA/tmux_cluster.sh create_wins session_name [hosts...]
  SESSION_NAME=$1
  shift
  IPS=("$@")

  # Check if the tmux session exists; if not, create it and detach
  if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux new-session -d -s "$SESSION_NAME" -n "${IPS[0]}"
  fi

  tmux send-keys -t "${SESSION_NAME}:0" "ssh ${IPS[0]}" C-m

  # Create a new window for each additional IP and ssh
  start_idx=1
  for ((i=start_idx;i<${#IPS[@]};i++)); do
    ip="${IPS[$i]}"
    tmux new-window -t "$SESSION_NAME" -n "$ip"
    tmux send-keys -t "${SESSION_NAME}:$i" "ssh $ip" C-m
  done
}

interactive_term_win() {
  SESSION_NAME=$1  # the tmux session
  shift
  # Get window indices to avoid window-name issues
  WIN_INDEXES=($(tmux list-windows -t "$SESSION_NAME" -F "#{window_index}")) # List of window indices

  echo "Enter commands to send to all windows. Type 'exit' to quit."
  while true; do
    # Use 'read -r -p' to preserve backslashes and prevent interpretation of escape characters (e.g., \" stays as \")
    read -r -p "> " INPUT  # This preserves backslashes and keeps INPUT as literally entered
    if [ "$INPUT" = "EXIT" ]; then
      break
    fi

    if [ "$INPUT" = "INT" ]; then
      for WIN_IDX in "${WIN_INDEXES[@]}"; do
        PANE_ID=$(tmux list-panes -t "${SESSION_NAME}:$WIN_IDX" -F "#{pane_id}" | head -n 1)
        tmux send-keys -t "$PANE_ID" C-c
      done
      continue
    fi

    for WIN_IDX in "${WIN_INDEXES[@]}"; do
      PANE_ID=$(tmux list-panes -t "${SESSION_NAME}:$WIN_IDX" -F "#{pane_id}" | head -n 1)
      tmux send-keys -t "$PANE_ID" "$INPUT" C-m
    done
  done
}


$1 "${@:2}"
