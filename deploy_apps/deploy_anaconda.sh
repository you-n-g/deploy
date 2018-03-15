#!/bin/bash

# Please install anaconda manually first.
# https://www.anaconda.com/download/#linux

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

conda create -n py27 python=2.7
