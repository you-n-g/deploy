#!/bin/bash

# Please install anaconda manually first.
# https://www.anaconda.com/download/#linux

# some
sudo apt-get install python-dev libmysqlclient-dev



# install some essential scripts
conda install -y tensorflow-gpu keras-gpu
conda install -y pandas matplotlib ipywidgets scikit-learn  # some software we should reinstall if we recreate a new environment
pip install mysqlclient  # for python3

conda install -c conda-forge -y jupyter_contrib_nbextensions
jupyter contrib nbextension install --user

for plg in toc2/main select_keymap/main execute_time/ExecuteTime scratchpad/main
do
    jupyter nbextension enable $plg
done

conda create -n py27 python=2.7
