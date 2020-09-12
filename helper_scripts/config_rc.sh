

FILE=~/deploy/configs/shell/rcfile.sh
if [ ! -f "$FILE" ]; then
    mkdir -p ~/.dotfiles/
    ln -s $FILE ~/.dotfiles/
fi


if ! grep "^source ~/.dotfiles/rcfile.sh" $RC_FILE ; then
    echo 'source ~/.dotfiles/rcfile.sh' >> $RC_FILE
fi
