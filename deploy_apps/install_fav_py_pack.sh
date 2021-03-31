#!/bin/bash
# install some essential scripts
# conda install -y tensorflow-gpu keras-gpu
conda install -y pandas matplotlib ipywidgets scikit-learn seaborn ipyparallel # some software we should reinstall if we recreate a new environment
conda install -y -c conda-forge python-cufflinks
# sudo apt-get install -y libmysqlclient-dev  # https://stackoverflow.com/a/5178698
# pip install mysqlclient  # for python3
# pip install tensorboardX
# conda install -y tensorboard
pip install papermill ipdb nbresuse jupytext
# - jupytext: 必须先安装再启动jupyter， 不然不会自动帮你保存py文件
conda install -y xlwt

# 这些都是针对个人用户的， 别人安装了没有用
conda install -c conda-forge -y jupyter_contrib_nbextensions
jupyter contrib nbextension install --user

for plg in toc2/main select_keymap/main execute_time/ExecuteTime scratchpad/main notify/notify codefolding/main collapsible_headings/main snippets/main
do
    jupyter nbextension enable $plg
done

# conda create -y -n py27 python=2.7


# for developing environment
pip install autopep8 better_exceptions neovim ipython-autotime yapf fire

# candidates packages
# - https://github.com/tartley/colorama

# snippets for juypter
DIR_P=$(jupyter --data-dir)/nbextensions/snippets/
FILE_P=$DIR_P/snippets.json
# if [ ! -e $DIR_P  ] || ! grep 'general import' $FILE_P
# then
#     mkdir -p $DIR_P
#     cat > $FILE_P <<EOF
# {
#     "snippets" : [
#         {
#             "name" : "general import",
#             "code" : [
#                 "import numpy as np",
#                 "import pandas as pd",
#                 "import matplotlib.pyplot as plt",
#                 "import seaborn as sns; sns.set(color_codes=True)",
#                 "plt.rcParams['font.sans-serif'] = 'SimHei'",
#                 "plt.rcParams['axes.unicode_minus'] = False",
#                 "from tqdm.auto import tqdm",
#                 "# tqdm.pandas()  # for progress_apply",
#                 "%matplotlib inline",
#                 "%load_ext autoreload"
#             ]
#         },
#         {
#             "name" : "sys path insert",
#             "code" : [
#                 "import sys",
#                 "sys.path.append('~/repos/data_selection')"
#             ]
#         }
#     ]
# }
# EOF
# fi
rm $FILE_P
ln -s ~/deploy/configs/jupyter/snippets.json $FILE_P


cd ~/deploy/
python deploy_apps/deploy_plot_cn_font.py

sh deploy_apps/set_jupyter_pwd.sh
