#!/bin/bash
DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"
cd $DIR

# if pipx does not exist, otherwise activate anaconda and add the PATH
# - in case of the first installation of pipx
if ! which pipx ; then
  . ~/miniconda3/etc/profile.d/conda.sh
  conda activate base
  export PATH="$PATH:$HOME/.local/bin"
fi

# NOTE: this does not work if we only add `.gitmodules` without commit..
# git submodule update --init --recursive
# So we have to finnaly mannually clone and update them.

grep url $DIR/../.gitmodules  | cut -d'=' -f2 | xargs -I % git clone %

for p in $(find . -maxdepth 1 -type d); do
  if [ "$p" == "." ]; then
    continue
  fi

  cd $DIR/$p
  git pull
  # make dev  # this will install package in `pipenv` instead of global.
  pipx install -e .
done
