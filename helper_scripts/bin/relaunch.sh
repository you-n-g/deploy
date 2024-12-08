#!/bin/bash
# NOTE: timeout may be a easier solution....

SLEEP_INTERVAL=${SLEEP_INTERVAL:-1800} # set to 1800 if not provided

# This script will relaunch the command followed by it for a fixed interval.
# If the command is still running, it will kill it and relaunch it.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <command>"
  exit 1
fi

COMMAND="$@"

while true; do
  timeout -s INT $SLEEP_INTERVAL $COMMAND
  sleep $SLEEP_INTERVAL
done
