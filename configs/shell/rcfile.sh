alias gitlog="git log --all --oneline --graph --decorate"
alias mux=tmuxinator
alias mx=tmux
export PATH="$HOME/bin/:$HOME/apps/nodejs/bin/:$PATH"
export EDITOR=`which vim`
# sudo -E will keep the environment when run sudo. Many env variables like http_proxy need it.
alias sudo="sudo -E"
export BETTER_EXCEPTIONS=1


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


alias pypdb='python -m ipdb -c c'
alias pyprof='python -m cProfile -o stats_out'

# for fzf
# 文件太大常常没法正常运行
export FZF_ALT_C_COMMAND="command find -L . -maxdepth 1 \\( -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
                         -o -type d -print 2> /dev/null | cut -b3-"

# We don't want to follow the link. This usually consumes a lot of time
export FZF_CTRL_T_COMMAND="command find . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' -o -path '*/mlruns/*' -o -path '*/__pycache__' -o -name '*.pyc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"
