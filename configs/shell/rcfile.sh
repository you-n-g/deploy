# # Outlines: Zsh only
# NOTE:
# - This should be included after conda because it leverages some conda-related features.

if [ `basename "$SHELL"` = zsh -o "$0" = '-zsh' ]; then
    ZF_CMD=$(cat<<"EOF"
z -l | sort -h -r | awk '{ print $2 }' | fzf --preview="echo {} | xargs ls -lat"
EOF
)
    if [ ! -e ~/antigen.zsh ]; then
        ln -s ~/.antigen.zsh  ~/antigen.zsh
	# https://github.com/zsh-users/antigen/issues/743
	# NOTE: this is caused by a bug of antigen
    fi
    function zf() {
            local dir=$(eval $ZF_CMD)
            cd "$dir"
    }

    function hf()  {
        # select commands from history
        history | grep -v -P '^ *\d+  history|less|ls' | fzf --tac -m | awk '{$1="";print}'
        # Ref: https://stackoverflow.com/questions/2626274/print-all-but-the-first-three-columns
    }
    # antigen use oh-my-zsh
    # 
    antigen bundle zsh-users/zsh-autosuggestions
    antigen bundle zsh-users/zsh-completions
    antigen bundle zsh-users/zsh-syntax-highlighting
    antigen bundle colored-man-pages
    antigen bundle rupa/z z.sh
    antigen bundle MichaelAquilina/zsh-you-should-use
    # antigen bundle mafredri/zsh-async
    # TODO: this give error now. But I can't remember why I need this plugin..

    # 后来发现 pure 似乎不能用 antigen 安装了
    # antigen bundle sindresorhus/pure

    # antigen theme denysdovhan/spaceship-prompt
    # TODO: 后面对spaceship-prompt 做做加速
    # echo $SPACESHIP_PROMPT_ORDER
    # NOTE: 这个会导致vim下，出现显示不出来的错误

    antigen theme romkatv/powerlevel10k

    antigen bundle paoloantinori/hhighlighter
    # hhighlighter
    # 1) 可以让一些暂时不支持高亮的代码 log 等等信息高亮
    # 2) 充当不能筛选内容的grep的作用

    # 有用的功能
    # C-x C-e 被 vv 替代掉了
    antigen bundle jeffreytse/zsh-vi-mode

    antigen bundle Aloxaf/fzf-tab

    # It does not work due to permission error
    # antigen bundle atuinsh/atuin@main

    antigen apply

    # 后面遇到问题是不是用 zplug可以替代

    # DEBUG:
    # 1. 如果发现 antigen一直不生效，但是在console中有效，请检查是不是在其他地方改了antigen
    # - 我感觉这个错误还会引发 zsh的segment faults: https://github.com/rvm/rvm/issues/4214
    #                                               Ref:https://github.com/zsh-users/antigen/issues/297
    # 2. 如果发现antigen 改配置后一直不生效， 可以考虑 antigen reset

    # export PURE_CMD_MAX_EXEC_TIME=1

    export SPACESHIP_TIME_SHOW=true
    # export SPACESHIP_DIR_TRUNC=false

    export SPACESHIP_PROMPT_ORDER=(time user dir host git package node docker venv conda dotnet exec_time battery jobs exit_code char)
    # TODO: vi_mode  pyenv can't be displayed correctly now..

    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    P10K_CONF=~/deploy/configs/shell/p10k.zsh
    [[ ! -f $P10K_CONF ]] || source $P10K_CONF

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
    
    # spaceship-prompt 可以直接显示时间
    # export PROMPT="[%D{%H:%M:%S}] $PROMPT"


    ZVM_VI_SURROUND_BINDKEY="s-prefix"

    # NOTE:
    # zsh vim mode 常常会和其他的插件起冲突(启用后会覆盖其他插件)
    # 所以很多插件需要 后面再补一发启动
    function zvm_after_init() {
        [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
        enable-fzf-tab
        # 有时候光有 zvm_after_lazy_keybindings 似乎也不work
        zvm_bindkey viins '^S^L' insert-last-word
    }

    function zvm_after_lazy_keybindings() {
        # 这个按键绑定在 zvm 上不work
        # bindkey -M viins '\e.' insert-last-word
        # - 一般的shell中的就是 ESC + .
        zvm_bindkey viins '^S^L' insert-last-word
    }
fi


# # Outlines: Bash Only




# # Outlines: Common config

alias gitlog="git log --all --oneline --graph --decorate # --reflog"
alias gitlogs="git log --all --pretty=short --abbrev-commit --graph --decorate # --reflog"
alias mux=tmuxinator
alias mx=tmux
export PATH="$HOME/deploy/helper_scripts/bin/:$HOME/bin/:$HOME/apps/nodejs/bin/:$HOME/.luarocks/bin/:$PATH"
export PATH="$PATH:$HOME/.local/bin"  # this is for pipx
export MANPATH="$HOME/.local/share/man/:$MANPATH"
export EDITOR=`which vim`
# sudo -E will keep the environment when run sudo. Many env variables like http_proxy need it.
alias sudo="sudo -E"
# export BETTER_EXCEPTIONS=1

# export LD_LIBRARY_PATH=/home/xiaoyang/lib/glibc/glibc-2.28-install/lib/:$LD_LIBRARY_PATH


function proxy_up() {
    # don't capitalize them
    export http_proxy=127.0.0.1:6489
    export https_proxy=127.0.0.1:6489
    export SOCKS_SERVER=127.0.0.1:8964
    # NOTICE: the ip range my not works on some softwares !!!!!
    export no_proxy=localhost,127.0.0.1,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.sock
    # To make it works for all softwares, proxychains is recommended
    # - socks4 should be used for `ssh -D` proxy.
    #    - I don't know why it doesn't work for tsocks when using specific software like thriftpy2(in jkdatasdk)
}

function proxy_down() {
    unset http_proxy https_proxy SOCKS_SERVER no_proxy
}



alias pypdb='python -m ipdb -c c'
alias pyprof='python -m cProfile -o stats_out'

alias ipify="curl cip.cc"
# using this alias name  because the previous tool is ipify

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

# ## Outlines: color
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'


# # Outlines: envs

export GOROOT="$HOME/apps/go/"
export PATH="$GOROOT/bin/:$PATH"

# config for go,  vim-go依赖这一步
export GOPATH="$HOME/gopath/"
export PATH="$GOPATH/bin/:$PATH"


# If the / is full, some command like pip install may fail. So we change the tmpdir to home directly
export TMPDIR=~/tmp/

export GPG_TTY=$(tty)  # for microsoft pull to use gpg to save 


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

    # 最后用的方法是 zsh 的插件h
}


# ## Outlines: ranger
# ranger的安装依赖  deploy_apps/install_fav_py_pack.sh
alias .r=". ranger"
# 其他
# -快捷键篇
#   - r: 可以open_with调用当前文件，1是less/pager
#       - 这个的好处是有时候vim比较慢，用其他工具就不会那么卡
# - 坑篇
#   - 如果 发现 dd pp 无法剪切文件(但是能复制文件)， 可能是权限 (这里的ranger是不会报错的)

# ## Outlines: conda

# Support tmux inherit the conda env

# this is not necessary, tmux will set the environment automatically
# env_expr=$(tmux show-environment conda_env 2> /dev/null)
# if [ $? -eq 0 -a "$env_expr" != "-conda_env" ]; then
#     eval "export $env_expr"
# fi

if [ -n "$conda_env" -a "$conda_env" != "base" ]; then
    conda activate $conda_env
fi


if [ "$pip_env" = "1" ]; then
    pipenv shell
fi

if [ "$pdm_env" = "1" ]; then
    `pdm venv activate`
fi


function yxca() {
    conda activate $1
    export conda_env=$1
    tmux setenv conda_env $1
}

function yxcd() {
    conda deactivate
    unset conda_env
    tmux setenv -r conda_env
}

function pipenva() {
    tmux setenv pip_env 1  # this must come before
    pipenv shell
}

function pipenvd() {
    tmux setenv -r pip_env
    exit
}

function pdma() {
    tmux setenv pdm_env 1  # this must come before
    `pdm venv activate`
}

function pdmd() {
    tmux setenv -r pdm_env
    echo "Please restart the shell to deactivate the pdm environment"
}


function deploy_quant_libs() {
  mkdir -p libs/
  cd libs
  pip install numpy
  pip install --upgrade  cython
  git clone https://github.com/microsoft/qlib.git
  cd qlib/
  pip install -e '.[dev]'
  git clone https://you-n-g@dev.azure.com/you-n-g/qutils/_git/qutils
  cd qutils/
  pip install -e .
}


# # Outlines: For apps

AIDER_CHECK_UPDATE=False

# # Outlines: 准备删掉的

# ## Outlines: nnn

export NNN_OPENER=~/apps/nnn/plugins/nuke

