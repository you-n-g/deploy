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

# If $MY_ENV is not .env, backup .env (if it exists) and link .env to $MY_ENV.
# NOTE:  I think this behavior may bring confusion.
# if [ "$MY_ENV" != ".env" ]; then
#   if [ -e ".env" ] && [ ! -L ".env" ]; then
#     echo "Backing up existing .env to .env.bak"
#     cp .env .env.bak
#     rm .env
#   fi
#   if [ -e "$MY_ENV" ]; then
#     # Only create or update .env symlink if it doesn't already point to $MY_ENV
#     if [ ! -L ".env" ] || [ "$(readlink .env)" != "$MY_ENV" ]; then
#       ln -sf "$MY_ENV" .env
#       echo "Linked .env -> $MY_ENV"
#     fi
#   else
#     echo "Warning: $MY_ENV does not exist. No link created."
#   fi
# fi

# EXTRA_DOTENV_ARGS is another considered environment variable.
# for example: `-f .another.env`
# NOTE: It only use the last .env

run_single_env() {
  local env_file=$1
  echo "loading ${env_file}..."
  if command -v dotenv &> /dev/null; then
    printf "%q " dotenv -f "$env_file" $EXTRA_DOTENV_ARGS run -- "${@:2}"; echo
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
