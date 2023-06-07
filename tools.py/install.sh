#!/bin/bash

git submodule update --init --recursive

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

for p in $(find . -type d -maxdepth 1); do

  if [ "$p" == "." ]; then
    continue
  fi

  cd $DIR/$p
  # make dev  # this will install package in `pipenv` instead of global.
  pipx install -e .
done
