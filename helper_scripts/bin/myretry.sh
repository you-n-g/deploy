#!/bin/sh

CMD="$@"
until $CMD; do
    echo "Command failed. Retrying in 10 seconds..."
    sleep 10
done
echo "Command succeeded."
