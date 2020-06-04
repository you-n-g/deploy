#!/bin/bash
set -x
source ~/.bashrc

DIR_PATH=`dirname "$0"`
DIR_PATH=`cd "$DIR_PATH"; pwd`

if [ ! -e ~/bin/vim ]; then
    mkdir -p ~/bin/
    curl -L  -o ~/bin/vim https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
    chmod a+x ~/bin/vim
fi

# FIXME: 这里在国内有可能被墙
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim



# this relys on the anaconda
pip install neovim
pip install jupytext



mkdir -p ~/.config/nvim/
cp ~/code_tools_repo/code_to_copy/backend/etc/init.vim ~/.config/nvim/




~/bin/vim -c PlugInstall -c qa


# cd ~/.vim/plugged/YouCompleteMe/ && python install.py  # I don't use YCM any longer


if ! grep "escape-time" ~/.tmux.conf ; then
    cat >> ~/.tmux.conf <<EOF
# for neovim
set-option -sg escape-time 10
set-option -sa terminal-overrides ',screen-256color:RBG'
EOF
fi

# deploy nodejs
# curl -sL install-node.now.sh/lts | sudo bash -s --  -y
# sudo npm install -g neovim  # TODO: make sure this line is right

# TODO: check current lines can replace the above lines
$DIR_PATH/deploy_nodejs.sh
NP=~/apps/nodejs
export PATH="$NP/bin/:$PATH"
$NP/bin/npm -g neovim


# :CocConfig 可以改变settings
# :CocLocalConfig 如果需要每个项目有自己的配置文件
mkdir -p ~/.config/nvim/
cat > ~/.config/nvim/coc-settings.json <<EOF
{
    "python.linting.pylamaArgs": ["-i E501,E402"],
    "explorer.icon.enableNerdfont": true,
    "list.source.files.excludePatterns": ["**/__pycache__/**", "**/mlruns/**", "**/runs/**", "**/*.pkl"]
}
EOF


# FIXME: This will not work on centos system
TEMP_DEB="$(mktemp)" && wget -O "$TEMP_DEB" 'https://github.com/BurntSushi/ripgrep/releases/download/11.0.2/ripgrep_11.0.2_amd64.deb' && sudo dpkg -i "$TEMP_DEB"
rm -f "$TEMP_DEB"



# docs about neovim
## other useful features of neovim
## - 在tmux中用 '*' and '+' 寄存器会直接和tmux的寄存器相连接
