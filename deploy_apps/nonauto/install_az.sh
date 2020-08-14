#!/bin/sh

if [ xiaoyang != root \]; then
    echo Please run this script as root or using sudo
    exit
fi

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 参考
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest
