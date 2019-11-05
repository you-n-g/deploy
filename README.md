
# Introduction
This repo will install some tools and vim for development


# Requirements
The installation is only tested on ubuntu 14.04 && ubuntu 16.04.
These tools will be installed in your home directory.

If you are using ubuntu 14.04, vim 8 is needed. You can install with the following instruction.
```
sudo apt-get install -y git
cd ~
git clone https://github.com/you-n-g/deployment4personaluse
cd deployment4personaluse
./deploy_apps/install_vim8.sh  # not required if you use neovim

echo  "<your account> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/80-service
```

If you ssh from a new machine to a old machine, maybe you should run the `set_code.sh` script before installation


# Installation


```
cd ~
git clone https://github.com/you-n-g/deployment4personaluse
cd deployment4personaluse
./deploy.sh
```
