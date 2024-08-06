#!/bin/bash

if [ -e .env ]; then
  if command -v dotenv &> /dev/null; then
    dotenv run -- "$@"
  else
    echo "dotenv is not installed. Please install it to use this script."
    exit 1
  fi
else
  "$@"
fi
