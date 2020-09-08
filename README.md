
# Introduction
This toolkit has been tested on
- ubuntu 14.04
- ubuntu 16.04
- ubuntu 18.04

This repo will help you to deploy a friendly environment for a python programmer in your home directory. The following tools will be well-configured.
- neovim
- zsh
- miniconda
- tmux

# Installation


```
sudo apt-get install -y git
cd ~
git clone https://github.com/you-n-g/deployment4personaluse
# Not using visudo is very dangerous!!!  visudo is suggested!!!
echo  "your_account ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/80-personal

cd deployment4personaluse
./deploy.sh
```
