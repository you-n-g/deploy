#!/bin/bash
DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

# For windows servers, the name will be like  GCRAZGDWXXXX instead of GCRAZGDLXXXX
copier copy -l -f -d nodenumber=2007 tpl script/


# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# az extension add --name ssh
# az login --use-device-code

sudo -E bash script/gdl.sh


# Upload your key to https://aka.ms/gcrssh/

ssh -N -L 2222:127.0.0.1:22 FAREAST.xiaoyang@127.0.0.1 -p 11122  -i ~/.ssh/id_rsa
