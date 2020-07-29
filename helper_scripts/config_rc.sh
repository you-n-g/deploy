


mkdir -p ~/.dotfiles/
ln -s ~/deployment4personaluse/configs/shell/rcfile.sh ~/.dotfiles/


if ! grep "^source ~/.dotfiles/rcfile.sh" $RC_FILE ; then
    echo 'source ~/.dotfiles/rcfile.sh' >> $RC_FILE
fi
