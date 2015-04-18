#!/bin/bash

function _ssh_cmd() {
    # Usage: _ssh_cmd USER HOSTPREFIX BEGIN END COMMAND
    if [[ ${@:5} == '' ]]; then
        echo "A command must be provided!!!"
        return 1
    fi
    for suffix in `seq $3 $4`; do
        echo "============" ssh $1@$2$suffix  "${@:5}" ====================
        # The ssh is a non-interactive shell, so we must source /etc/profile explicitly.
        # The ENV variables should be added to /etc/profile
        ssh $1@$2$suffix  "source /etc/profile && ${@:5}"
    done
}

function _scp() {
    # Usage: _scp USER HOSTPREFIX BEGIN END PATH
    if [[ ${@:5} == '' ]]; then
        echo "A path must be provided!!!"
        return 0
    fi
    for suffix in `seq $3 $4`; do
        echo "============" scp "$@" $1@$2$suffix:~/  ====================
        scp "${@:5}" $1@$0$suffix:~/
    done
}

# These command may be defined
# function allcmd()
# function mncmd() 


# what would usally du for a cluster
# 1) set hosts
# 2) copy keys from masters to slaves
# 3) add this helper script
# 4) set envs like proxys to /etc/profile (because ssh is a non-interactive shell)
