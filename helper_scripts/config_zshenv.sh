if ! grep "^source ~/deploy/configs/shell/env.sh" "$ZSHENV_FILE" >/dev/null 2>&1; then
    echo 'source ~/deploy/configs/shell/env.sh' >> "$ZSHENV_FILE"
fi
