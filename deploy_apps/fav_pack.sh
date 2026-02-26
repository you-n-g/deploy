#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR
npm i -g @openai/codex
# npm i -g ccman
./config_codex.py
