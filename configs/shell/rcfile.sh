# # Outlines: Zsh only

if [ `basename "$SHELL"` = zsh -o "$0" = '-zsh' ]; then
    ZF_CMD=$(cat<<"EOF"
z -l | sort -h -r | awk '{ print $2 }' | fzf --preview="echo {} | xargs ls -lat"
EOF
)
    function zf() {
            local dir=$(eval $ZF_CMD)
            cd "$dir"
    }

    function hf()  {
        # select commands from history
        history | grep -v -P '^ *\d+  history|less|ls' | fzf --tac -m | awk '{$1="";print}'
        # Ref: https://stackoverflow.com/questions/2626274/print-all-but-the-first-three-columns
    }
    antigen bundle zsh-users/zsh-autosuggestions
    antigen bundle zsh-users/zsh-completions
    antigen bundle zsh-users/zsh-syntax-highlighting
    antigen bundle colored-man-pages
    antigen bundle rupa/z z.sh
    antigen bundle MichaelAquilina/zsh-you-should-use
    antigen bundle mafredri/zsh-async
    antigen bundle sindresorhus/pure
    antigen bundle paoloantinori/hhighlighter
    # hhighlighter
    # 1) 可以让一些暂时不支持高亮的代码 log 等等信息高亮
    # 2) 充当不能筛选内容的grep的作用
    antigen apply

    export PURE_CMD_MAX_EXEC_TIME=1

    # shrink path
    # export PROMPT='${ret_status} %{$fg[cyan]%}$(shrink_path -l -t) %{$reset_color%}'

    # For showing time
    # show right prompt with date ONLY when command is executed
    # strlen () {
    #     FOO=$1
    #     local zero='%([BSUbfksu]|([FB]|){*})'
    #     LEN=${#${(S%%)FOO//$~zero/}}
    #     echo $LEN
    # }

    # 因为pure可以显示运行时间， prompt又加了prompt出现的时间节点，所以敲命令的时间和实际的执行时间都可以推算出来
    # FIXME: 这里在tmux + pure主题下时，时间设置会多一行
    # preexec () {
    #     DATE=$( date +"[%H:%M:%S]" )
    #     local len_right=$( strlen "$DATE" )
    #     len_right=$(( $len_right+1 ))
    #     local right_start=$(($COLUMNS - $len_right))
    #
    #     local len_cmd=$( strlen "$@" )
    #     local len_prompt=$(strlen "$PROMPT" )
    #     local len_left=$(($len_cmd+$len_prompt))
    #
    #     RDATE="\033[${right_start}C ${DATE}"
    #
    #     if [ $len_left -lt $right_start ]; then
    #         # command does not overwrite right prompt
    #         # ok to move up one line
    #         echo -e "\033[1A${RDATE}"
    #     else
    #         echo -e "${RDATE}"
    #     fi
    # }
    # https://stackoverflow.com/a/26585789
    export PROMPT="[%D{%H:%M:%S}] $PROMPT"

    bindkey -M viins '\e.' insert-last-word
fi


# # Outlines: Bash Only




# # Outlines: Common config

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

alias ipify="curl 'https://api.ipify.org?format=json'"

# for fzf
# 文件太大常常没法正常运行
export FZF_ALT_C_COMMAND="command find -L . -maxdepth 1 \\( -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
                         -o -type d -print 2> /dev/null | cut -b3-"

# We don't want to follow the link. This usually consumes a lot of time
export FZF_CTRL_T_COMMAND="command find . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' -o -path '*/mlruns/*' -o -path '*/__pycache__' -o -name '*.pyc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"

export FZF_DEFAULT_COMMAND='fd --type f -L'

# for rvm and tmuxinator
# 优先使用个人账户下的rvm
if [ -e $HOME/.rvm/scripts/rvm ]; then
    source $HOME/.rvm/scripts/rvm
fi



# # Outlines: tools

function tfts() {
    # 只有用这个trick才能保证最后一行能被立马读出来
    # 但是这个性能非常慢
    # pip install rainbow
    # tail -f -n 20 $1 |  ts '[%Y-%m-%d %H:%M:%S]'  | while read _line
    # do
    #     # stdbuf -i0 -o0 -e0 echo "$_line"
    #     echo "$_line" #| rainbow -f $2
    #     echo 'xixihaha'
    # done  | rainbow -f $2 | sed "/xixihaha/d"  

    # 这个是无法支持实时数据流的
    # tail -f -n 20 $1 | awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0 }'
    
    LINE_N=${2:-100}
    tail -f -n $LINE_N $1 | ts '[%Y-%m-%d %H:%M:%S]'

    # 不需要协程下面的样子的
    # tail -f -n 20 $1 | ts '[%Y-%m-%d %H:%M:%S]' | while read _line
    # do
    #     echo "$_line"
    # done
}

