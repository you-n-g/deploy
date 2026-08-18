#!/bin/bash
set -x

# TODO: 还没检查重新安装是否是有用的
# - 这里发现第一次根本不会认得conda

export PATH="$HOME/anaconda3/bin:$HOME/miniconda3/bin:$PATH"   # for enable conda after installation

# if which conda ;
# then
#     conda install -c conda-forge -y tmux
#     # TMUX_EXE=$CONDA_PREFIX/bin/tmux
#     TMUX_EXE=~/miniconda3/bin/tmux
#     # 这里硬编码了， 但是也没有更好的，一直找不到环境变量
# else
#     TMUX_EXE=`which tmux`
# fi

# 这个地方是为了无论在哪个 conda 环境中， 都能找到正常的tmux
# 需要下面的假设成立
# - ~/bin/ 被加到了PATH中，这个依赖 rcfile.sh
# 如果不加这个会导致
# - 在老的系统中找不到正确版本的tmux，导致 vim-slime, ranger 之类的软件失效(失效表现为遇到tmux相关的的步骤就卡住)
# ln -s $TMUX_EXE ~/bin/tmux

# tmux is preferably provided by `module add tmux-latest` (configs/shell/modules.sh).
# Our tmux.conf needs >=3.2 (display-popup). Only install when the tmux on PATH
# is missing or too old.
TMUX_MIN_VERSION=3.2
tmux_version_ok() {
    command -v tmux >/dev/null 2>&1 || return 1
    # tmux -V -> "tmux 3.7b" / "tmux 3.1"; keep only the leading number.
    local cur
    cur=$(tmux -V | sed -E 's/^tmux[[:space:]]+([0-9]+\.[0-9]+).*/\1/')
    # true when cur >= TMUX_MIN_VERSION (sort -V puts the min first)
    [ "$(printf '%s\n%s\n' "$TMUX_MIN_VERSION" "$cur" | sort -V | head -n1)" = "$TMUX_MIN_VERSION" ]
}

if tmux_version_ok ; then
    echo "tmux $(tmux -V) is new enough (>=$TMUX_MIN_VERSION); skipping install."
elif command -v brew >/dev/null 2>&1 ; then
    if ! brew list tmux >/dev/null 2>&1 ; then
        brew install tmux
        # this may take very long time
    fi
    brew link tmux >/dev/null 2>&1 || true
    TMUX_EXE=$(brew --prefix)/bin/tmux
else
    echo "Homebrew not found, skipping brew-based tmux installation"
fi

# tmuxinator needs ruby/rvm; the script handles the already-installed case itself.
bash ~/deploy/deploy_apps/install_tmuxinator.sh


## config tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
TMUX_CONF=~/.tmux.conf
touch "$TMUX_CONF"

### color schema
# This will not work in GFW.
# This is replaced by egel/tmux-gruvbox installed by tpm
# wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O $TMUX_CONF

if ! grep "^source-file ~/deploy/configs/tmux/tmux.conf" $TMUX_CONF ; then
    echo 'source-file ~/deploy/configs/tmux/tmux.conf' >> $TMUX_CONF
fi


sh ~/deploy/deploy_apps/deploy_tpm.sh
