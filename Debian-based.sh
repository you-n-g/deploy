#!/bin/bash

# sudo add-apt-repository ppa:x4121/ripgrep -y
# ripgrep 不靠这个安装了

sudo apt-get update

# Essential
sudo apt-get install -y git build-essential cmake python-dev htop zsh autossh exuberant-ctags
# Optional (the installation of these softwares may fail due to different system versions)
sudo apt-get install -y vim vim-nox tmux \
	clang python-flake8 python-pip software-properties-common silversearcher-ag moreutils # this line is for common use

# sudo apt-get install -y gnupg2
# ruby和 rvm 后面都选择在 ./deploy_apps/install_tmuxinator.sh 中在个人账户安装
# sudo apt-get install -y software-properties-common
# sudo apt-add-repository -y ppa:rael-gc/rvm
# sudo apt-get update
# sudo apt-get install -y rvm  # this is for installing latest
# sudo su - $USER -c 'rvm install ruby'
# sudo su - $USER -c 'gem install tmuxinator'

# sudo apt-get install -y tmuxinator  # this will be installed by gem

sudo apt-get install -y ack-grep # TODO: 可能是不必须的
sudo apt-get install -y cloc

# clang is for YCM
# python-flake8 is needed by vim-flake8

# dpkg-reconfigure locales  # 配置成 LANG=en_US.UTF-8 就可以了
