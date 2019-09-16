#!/bin/sh
if [ ! -e ~/bin/vim ]; then
    mkdir -p ~/bin/
    curl -L  -o ~/bin/vim https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
    chmod a+x ~/bin/vim
fi

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim



# this relys on the anaconda
pip install neovim



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

curl -sL install-node.now.sh/lts | sudo bash -s --  -y
npm install -g neovim  # TODO: make sure this line is right

~/bin/vim -c "CocInstall coc-python" -c qa
~/bin/vim -c "CocInstall coc-highlight" -c qa
~/bin/vim -c "CocInstall coc-lists" -c qa
~/bin/vim -c "CocInstall coc-json" -c qa

# :CocConfig可以改变settings
mkdir -p ~/.config/nvim/
cat > ~/.config/nvim/coc-settings.json <<EOF
{
    "python.linting.pylamaArgs": ["-i E501"]
}
EOF


TEMP_DEB="$(mktemp)" && wget -O "$TEMP_DEB" 'https://github.com/BurntSushi/ripgrep/releases/download/11.0.2/ripgrep_11.0.2_amd64.deb' && sudo dpkg -i "$TEMP_DEB"
rm -f "$TEMP_DEB"
