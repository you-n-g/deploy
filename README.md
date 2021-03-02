
# Introduction
This repo will help you to deploy a friendly environment for a python programmer in your home directory. The following tools will be well-configured.
- neovim
- zsh
- miniconda
- tmux



# My Config and Installation Scripts for Tools
User could find the individual config and installation scripts below.

| Tools     | Config Path                                        | Installation script                                                |
|-----------|----------------------------------------------------|--------------------------------------------------------------------|
| neovim    | [configs/nvim/](configs/nvim/)                     | [deploy_apps/install_neovim.sh](deploy_apps/install_neovim.sh)     |
| zsh       | [configs/shell/rcfile.sh](configs/shell/rcfile.sh) | [deploy_apps/install_zsh.sh](deploy_apps/install_zsh.sh)           |
| miniconda | -                                                  | [deploy_apps/deploy_miniconda.sh](deploy_apps/deploy_miniconda.sh) | 


# Installation
I would like to install all the environment in a single command(This is experimental).

```
sudo apt-get install -y git curl
cd ~
git clone https://github.com/you-n-g/deploy
# Not using visudo is very dangerous!!!  visudo is suggested!!!
echo  "your_account ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/80-personal

cd deploy
./deploy.sh
```
