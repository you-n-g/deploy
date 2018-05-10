#!/bin/bash

# Please install anaconda manually first.
# https://www.anaconda.com/download/#linux
if [ ! -e ~/anaconda3/ ]; then
    mkdir -p ~/tmp/
    cd ~/tmp/
    wget https://repo.continuum.io/archive/Anaconda3-5.1.0-Linux-x86_64.sh -O Anaconda3-latest-Linux-x86_64.sh
    sh Anaconda3-latest-Linux-x86_64.sh
fi

. ~/.bashrc

conda update --all


# some
sudo apt-get install -y python-dev libmysqlclient-dev



# install some essential scripts
conda install -y tensorflow-gpu keras-gpu
conda install -y pandas matplotlib ipywidgets scikit-learn  # some software we should reinstall if we recreate a new environment
# sudo apt-get install -y libmysqlclient-dev  # https://stackoverflow.com/a/5178698
pip install mysqlclient  # for python3
pip install papermill
conda install -y xlwt

conda install -c conda-forge -y jupyter_contrib_nbextensions
jupyter contrib nbextension install --user

for plg in toc2/main select_keymap/main execute_time/ExecuteTime scratchpad/main
do
    jupyter nbextension enable $plg
done

# conda create -y -n py27 python=2.7


# for developing environment
pip install autopep8 better_exceptions

echo 'export PATH="/home/xiaoyang/anaconda3/bin:$PATH"' >> ~/.zshrc
