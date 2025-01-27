#!/bin/bash


false << "EOF" > /dev/null
A typical content in .conf.env
export PYTHONPATH=<absolute path>
EOF

if [ -e '.conf.env' ]; then
  echo '`.conf.env` detected...'
  source .conf.env
fi

MY_ENV=${MY_ENV:-.env}
# EXTRA_DOTENV_ARGS is another considered environment variable.
# for example: `-f .another.env`

if [ -e $MY_ENV ]; then
  echo "loading ${MY_ENV}..."
  if command -v dotenv &> /dev/null; then
    echo dotenv -f $MY_ENV $EXTRA_DOTENV_ARGS run -- "$@"
    dotenv -f $MY_ENV $EXTRA_DOTENV_ARGS run -- "$@"
    # `--override` is the default option; we don't have to add it
  else
    echo "dotenv is not installed. Please install it (e.g. \`pip install python-dotenv\`) to use this script."
    exit 1
  fi
else
  "$@"
fi
