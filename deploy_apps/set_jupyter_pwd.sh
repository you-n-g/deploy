#!/bin/sh

# Set the password automatically

# `echo N` incase of overriding the existing config
echo N | jupyter notebook --generate-config

CONF_PATH=`jupyter --config-dir`/jupyter_notebook_config.py 
if  ! grep '^c.NotebookApp.password=' $CONF_PATH
then
    echo 'c.NotebookApp.password="argon2:$argon2id$v=19$m=10240,t=10,p=8$WzpkaM4Mk40os95Prk2h+Q$0C2O6jMN8iN44+D0mE4Kjg"' >> $CONF_PATH
fi
