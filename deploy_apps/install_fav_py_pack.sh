#!/bin/bash
# install some essential scripts
# conda install -y tensorflow-gpu keras-gpu
conda install -y pandas matplotlib ipywidgets scikit-learn seaborn ipyparallel # some software we should reinstall if we recreate a new environment
conda install -y -c conda-forge python-cufflinks
# sudo apt-get install -y libmysqlclient-dev  # https://stackoverflow.com/a/5178698
# pip install mysqlclient  # for python3
# pip install tensorboardX
# conda install -y tensorboard
pip install papermill ipdb nbresuse
conda install -y xlwt

# 这些都是针对个人用户的， 别人安装了没有用
conda install -c conda-forge -y jupyter_contrib_nbextensions
jupyter contrib nbextension install --user

for plg in toc2/main select_keymap/main execute_time/ExecuteTime scratchpad/main notify/notify codefolding/main collapsible_headings/main
do
    jupyter nbextension enable $plg
done

# conda create -y -n py27 python=2.7


# for developing environment
pip install autopep8 better_exceptions neovim ipython-autotime


# snippets
DIR_P=$(jupyter --data-dir)/nbextensions/snippets/
FILE_P=$DIR_P/snippets.json
if [ ! -e $DIR_P  ] || ! grep 'general import' $FILE_P
then
    mkdir -p $DIR_P
    cat > $FILE_P <<EOF
{
    "snippets" : [
        {
            "name" : "general import",
            "code" : [
                "import numpy as np",
                "import pandas as pd",
                "import matplotlib.pyplot as plt",
                "import seaborn as sns; sns.set(color_codes=True)",
                "plt.rcParams['font.sans-serif'] = 'SimHei'",
                "plt.rcParams['axes.unicode_minus'] = False",
                "from tqdm.auto import tqdm",
                "# tqdm.pandas()  # for progress_apply",
                "%matplotlib inline",
                "%load_ext autoreload"
            ]
        },
        {
            "name" : "sys path insert",
            "code" : [
                "import sys",
                "sys.path.append('/home/xiaoyang/repos/data_selection')"
            ]
        }
    ]
}
EOF
fi
