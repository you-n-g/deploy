#!/bin/bash
# install some essential scripts
# conda install -y tensorflow-gpu keras-gpu
conda install -y pandas matplotlib ipywidgets scikit-learn seaborn # some software we should reinstall if we recreate a new environment
conda install -y -c conda-forge python-cufflinks
# sudo apt-get install -y libmysqlclient-dev  # https://stackoverflow.com/a/5178698
# pip install mysqlclient  # for python3
pip install papermill ipdb
conda install -y xlwt

# 这些都是针对个人用户的， 别人安装了没有用
conda install -c conda-forge -y jupyter_contrib_nbextensions
jupyter contrib nbextension install --user

for plg in toc2/main select_keymap/main execute_time/ExecuteTime scratchpad/main notify/notify
do
    jupyter nbextension enable $plg
done

# conda create -y -n py27 python=2.7


# for developing environment
pip install autopep8 better_exceptions neovim
