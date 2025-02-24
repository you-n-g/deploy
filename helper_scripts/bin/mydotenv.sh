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
# NOTE: It only use the last .env

run_single_env() {
  local env_file=$1
  echo "loading ${env_file}..."
  if command -v dotenv &> /dev/null; then
    echo dotenv -f $env_file $EXTRA_DOTENV_ARGS run -- "${@:2}"
    dotenv -f $env_file $EXTRA_DOTENV_ARGS run -- "${@:2}"
    # `--override` is the default option we don't have to add it
  else
    echo "dotenv is not installed. Please install it (e.g. \`pip install python-dotenv\`) to use this script."
    exit 1
  fi
}

if [ -d $MY_ENV ]; then
  # if it is a folder, then we run commands for each env.
  for env_file in $MY_ENV/*.env; do
    run_single_env $env_file "$@"
  done
elif [ -e $MY_ENV ]; then
  run_single_env $MY_ENV "$@"
else
  "$@"
fi
