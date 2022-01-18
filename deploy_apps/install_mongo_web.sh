#!/bin/sh

# candidates
# - https://github.com/huggingface/Mongoku
# - https://github.com/mrvautin/adminMongo
# Mongoku is both young and hot

if [ $0 = "-bash" -o $0 = "-zsh" -o $0 = "zsh"  ]; then
    DIR=`pwd`
else
    DIR="$( cd "$(dirname $(readlink -f "$0"))" ; pwd -P )"
fi


sh $DIR/deploy_nodejs.sh

npm install -g mongoku

mongoku start
