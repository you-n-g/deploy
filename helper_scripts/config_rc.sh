if ! grep "^source ~/deploy/configs/shell/rcfile.sh" $RC_FILE ; then
    echo 'source ~/deploy/configs/shell/rcfile.sh' >> $RC_FILE
fi
