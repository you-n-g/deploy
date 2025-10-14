#!/bin/bash
DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"
cd $DIR

SKIP_INSTALL=0
# https://stackoverflow.com/a/34531699
while getopts ":k" opt; do
    case $opt in
        k)
        echo "-k was triggered, Parameter: $OPTARG" >&2
        SKIP_INSTALL=1
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

# if pipx does not exist, otherwise activate anaconda and add the PATH
# - in case of the first installation of pipx
if [[ $SKIP_INSTALL -eq 0 ]] && ! which pipx ; then
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
  # Python package
  git pull
  if [[ (-e "pyproject.toml" || -e "requirements.txt" || -e "setup.py") && $SKIP_INSTALL -eq 0 ]]; then
    # make dev  # this will install package in `pipenv` instead of global.
    pipx install -e .
  fi
done
