if ! grep "^alias gitlog" $RC_FILE ; then
	echo 'alias gitlog="git log --all --oneline --graph --decorate"' >> $RC_FILE
fi

if ! grep "^alias mux" $RC_FILE ; then
	echo 'alias mux=tmuxinator' >> $RC_FILE
fi

if ! grep "^alias mx" $RC_FILE ; then
	echo 'alias mx=tmux' >> $RC_FILE
fi

if ! grep "^export PATH" $RC_FILE ; then
    mkdir -p $HOME/bin/
	echo 'export PATH="$HOME/bin/:$PATH"' >> $RC_FILE
fi

if ! grep "^export EDITOR" $RC_FILE ; then
	echo 'export EDITOR=`which vim`' >> $RC_FILE
fi

if ! grep "^alias sudo" $RC_FILE ; then
    echo 'alias sudo="sudo -E"' >> $RC_FILE
    # sudo -E will keep the environment when run sudo. Many env variables like http_proxy need it.
fi

if ! grep "^export BETTER_EXCEPTIONS" $RC_FILE ; then
    echo 'export BETTER_EXCEPTIONS=1' >> $RC_FILE
fi

# proxy_related
if ! grep "^function proxy_up" $RC_FILE ; then
    cat >>$RC_FILE <<EOF
function proxy_up() {
    # don't capitalize them
    export http_proxy=127.0.0.1:6489
    export https_proxy=127.0.0.1:6489
    export SOCKS_SERVER=127.0.0.1:8964
    # NOTICE: the ip range my not works on some softwares !!!!!
    export no_proxy=localhost,127.0.0.1,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.sock
}
function proxy_down() {
    unset http_proxy https_proxy SOCKS_SERVER no_proxy
}
EOF
fi


# for fzf
# 文件太大常常没法正常运行
if ! grep "^export FZF_ALT_C_COMMAND" $RC_FILE ; then
    cat >>$RC_FILE <<"EOF"
export FZF_ALT_C_COMMAND="command find -L . -maxdepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
                         -o -type d -print 2> /dev/null | cut -b3-"
EOF
fi
