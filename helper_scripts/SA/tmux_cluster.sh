#!/bin/sh

create_panes() {
  # Usage: bash ~/deploy/helper_scripts/SA/tmux_cluster.sh create_panes {a,b,c,d}.afeyoung.icu

  # 1) we create a new tmux window for current session
  tmux new-window

  for ip in "$@" ; do
    # 2) for each ip, we create a pane with shell; and then input the ip address as a command into each pane respectively
    tmux split-window -h
    tmux send-keys "ssh $ip"
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
    # Read a line of input from the user
    read -p "> " INPUT

    # Exit the loop if the user types 'exit'
    if [ "$INPUT" = "exit" ]; then
      break
    fi

    # Loop through each pane and send the input
    for PANE in $PANES; do
      tmux send-keys -t "$PANE" "$INPUT" C-m
    done
  done
}

$1 "${@:2}"
