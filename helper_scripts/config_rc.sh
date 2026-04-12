if ! grep "^source ~/deploy/configs/shell/rcfile.sh" $RC_FILE ; then
    touch $RC_FILE
    echo 'source ~/deploy/configs/shell/rcfile.sh' >> $RC_FILE
fi
