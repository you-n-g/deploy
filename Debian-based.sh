#!/bin/bash

set -x

# TODO:
# It seems I have to manually restart the services  if when I install the packages

# sudo add-apt-repository ppa:x4121/ripgrep -y
# ripgrep 不靠这个安装了

sudo apt-get update

# several lines of packages
# 1) Essential
# 2) Optional (the installation of these softwares may fail due to different system versions)  # this line is for common use
for p in git build-essential cmake python-dev htop zsh autossh exuberant-ctags \
	 tmux clang software-properties-common silversearcher-ag moreutils ack-grep cloc ; do
    # in case of lacking specific package result in failing of all packages. So we just install them one by one
    sudo apt-get install -y $p
done

# sudo apt-get install -y gnupg2
# ruby和 rvm 后面都选择在 ./deploy_apps/install_tmuxinator.sh 中在个人账户安装
# sudo apt-get install -y software-properties-common
# sudo apt-add-repository -y ppa:rael-gc/rvm
# sudo apt-get update
# sudo apt-get install -y rvm  # this is for installing latest
# sudo su - $USER -c 'rvm install ruby'
# sudo su - $USER -c 'gem install tmuxinator'

# sudo apt-get install -y tmuxinator  # this will be installed by gem

# clang is for YCM
# python-flake8 is needed by vim-flake8

# dpkg-reconfigure locales  # 配置成 LANG=en_US.UTF-8 就可以了
