#!/bin/bash

# Known issues of the script
# - [ ] it may override `configs/jupyter/snippets.json`

# # Outlines: user-wise instead of environment-wise dependencies

python -m pip install --user pipx
python -m pipx ensurepath
export PATH="$PATH:$HOME/.local/bin"
pip install --user neovim pynvim
# `pipenv virtualenv` are not installed in this way due to it should bind with a specific python env
for p in pre-commit ranger-fm yapf black copier tldr; do
    # pipx will install things in user space
    pipx install $p
done
# other favorite candidates
# - pipx install asciinema
# NOTE: We suggest not installing the following package, pipx, as it is bound to your current environment.
# - pytest
#
# sometimes it will raise error, following code may solve this problem
# - pip install pip -U
# - pip install pipenv -U
# - pip install virtualenv -U


# # Outlines: environment-wise dependencies
# TODO: extract following system-wide dependencies to the above section.

# install some essential scripts
# conda install -y tensorflow-gpu keras-gpu
conda install -y pandas matplotlib ipywidgets scikit-learn seaborn ipyparallel # some software we should reinstall if we recreate a new environment
conda install -y -c conda-forge python-cufflinks shellcheck
# sudo apt-get install -y libmysqlclient-dev  # https://stackoverflow.com/a/5178698
# pip install mysqlclient  # for python3
# pip install tensorboardX
# conda install -y tensorboard
pip install papermill ipdb nbresuse jupytext # pdbpp
# - jupytext: 必须先安装再启动jupyter， 不然不会自动帮你保存py文件
# - pdbpp: sticky 功能非常好用!!!!
#   - NOTE: pdbpp is not compatible with jupyter debugging.

conda install -y xlwt
pip install openpyxl # for excel engine for pandas , xlrd is another choice

conda install -c conda-forge -y jupyter_contrib_nbextensions
# -  `jupyter nbconvert --to script` 这种命令需要它

conda install -c conda-forge -y pyarrow
# - this is for supporting parquet (data format decoupled with code and env)


# 这些都是针对个人用户的， 别人安装了没有用
jupyter contrib nbextension install  # --user

for plg in toc2/main select_keymap/main execute_time/ExecuteTime scratchpad/main notify/notify codefolding/main collapsible_headings/main snippets/main
do
    jupyter nbextension enable $plg
done

# conda create -y -n py27 python=2.7


# for developing environment
pip install autopep8 better_exceptions ipython-autotime fire pylint debugpy objexplore
# ruff-lsp #  ruff-lsp only give warnings and does not provide docs. So it can't replace pyright.


# candidates packages
# - https://github.com/tartley/colorama

# snippets for juypter
DIR_P=$(jupyter --data-dir)/nbextensions/snippets/
FILE_P=$DIR_P/snippets.json
rm "$FILE_P"
ln -s ~/deploy/configs/jupyter/snippets.json "$FILE_P"

if [[ ! -e ~/.pdbrc.py  ]]; then
    ln -s ~/deploy/configs/python/pdbrc.py ~/.pdbrc.py
fi


cd ~/deploy/
python deploy_apps/deploy_plot_cn_font.py

sh deploy_apps/set_jupyter_pwd.sh



# 一般常用的软件
pip install nose ipdbplugin

# jupyter_ascending.vim
pip install jupyter_ascending

jupyter nbextension install --py --sys-prefix jupyter_ascending
jupyter nbextension     enable jupyter_ascending --sys-prefix --py
jupyter serverextension enable jupyter_ascending --sys-prefix --py
# below is for checking if the extension is installed
# jupyter nbextension list
# jupyter serverextension list
# CONFIG & Usage: After installing the command above and vim plugin, you should also install notice following things:
# - you must specify the port before starting **both** vim and jupyter, e.g. `JUPYTER_ASCENDING_EXECUTE_PORT=9000`; 
#    - 这个端口要和jupyter的端口一致!!!
# - Make sure both of them can be accessed by 127.0.0.1, otherwise you should also set the IP by `JUPYTER_ASCENDING_EXECUTE_HOST=xxxxxxx`
# - Make sure the vim end can access without credentials ` --NotebookApp.token='' --NotebookApp.password=''`
#   - (by copilot)otherwise you should also set the credentials by `JUPYTER_ASCENDING_EXECUTE_TOKEN=xxxxxxx`
# - The name suffix `.sync` is nessary ;  :help g:jupyter_ascending_match_pattern
# - creating pair by `python -m jupyter_ascending.scripts.make_pair --base example`
# - You edit .py in vim, and run .ipynb in jupyter
# DEBUG:
# - `/tmp/jupyter_ascending/log.log` is typically the log file for debugging of jupyter_ascending
# - Base on my experience, you must restart the kernel after you install the plugin, otherwise it will not work
# Others:
# - autosave is controlled by magic function in jupyter like `%autosave 0`
