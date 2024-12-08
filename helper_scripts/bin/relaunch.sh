#!/bin/bash

SLEEP_INTERVAL=1800

# This script will relaunch the command followed by it for a fixed interval.
# If the command is still running, it will kill it and relaunch it.

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <command>"
    exit 1
fi

COMMAND="$@"
# Use md5 to get a unique name but will not change with the command.
# Add the first 3 elements in $@ as prefix (concatenated with _).
# If $@ does not have enough elements, use a shorter one.
PREFIX=$(echo "${1}_${2}_${3}" | tr ' ' '_' | sed 's/_*$//')
COMMAND_HASH=$(echo -n "$COMMAND" | md5sum | awk '{print $1}')
PID_FILE="./${PREFIX}_$COMMAND_HASH.pid"

cleanup() {
    echo "Cleaning up..."
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Command is running with PID $PID. Killing it..."
            kill -9 "$PID"
        else
            echo "Command is not running. Removing stale PID file."
            rm -f "$PID_FILE"
        fi
    fi

    # Relaunch the command
    echo "Relaunching the command..."
    $COMMAND &
    echo $! > "$PID_FILE"

    sleep $SLEEP_INTERVAL
done
