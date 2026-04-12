if ! grep "^source ~/deploy/configs/shell/env.sh" "$ZSHENV_FILE" >/dev/null 2>&1; then
    touch "$ZSHENV_FILE"
    echo 'source ~/deploy/configs/shell/env.sh' >> "$ZSHENV_FILE"
fi
