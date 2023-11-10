
# Introduction
This repo will help you to deploy a friendly environment for a Python programmer in your home directory. The following tools will be well-configured.
- neovim
- zsh
- miniconda
- tmux



# My Config/Dotfiles and Installation Scripts for Tools
User could find the individual config and installation scripts below.

| Tools     | Config/Dotfiles Path                               | Installation script                                                |
|-----------|----------------------------------------------------|--------------------------------------------------------------------|
| neovim    | [configs/lazynvim/](configs/lazynvim/)                     | [deploy_apps/nonauto/install_lazyvim.sh](deploy_apps/nonauto/install_lazyvim.sh)     |
| zsh       | [configs/shell/rcfile.sh](configs/shell/rcfile.sh) | [deploy_apps/install_zsh.sh](deploy_apps/install_zsh.sh)           |
| tmux      | [configs/tmux/](configs/tmux/)                     | [deploy_apps/install_tmux.sh](deploy_apps/install_tmux.sh)         |
| miniconda | -                                                  | [deploy_apps/deploy_miniconda.sh](deploy_apps/deploy_miniconda.sh) |

# Environment
It is mainly tested on ubuntu.

Ubuntu 18.04 or below is not supported now.
- mainly due to  [nodejs](deploy_apps/deploy_nodejs.sh)

# Installation
I would like to install all the environment with a single command(This is experimental).

```
sudo apt-get install -y git curl
cd ~
git clone https://github.com/you-n-g/deploy  # (Alternative) git clone git@github.com:you-n-g/deploy.git
# Not using visudo is very dangerous!!!  visudo is suggested!!!
echo  "your_account ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/80-personal

cd deploy
./deploy.sh # (Alternative if ssh clone instead of ssh) ./deploy.sh -s
```
