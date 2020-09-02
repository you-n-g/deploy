#!/bin/sh
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install  --completion --key-bindings --update-rc


# Tips
# 这里背后会遵守git ignore
# - https://github.com/junegunn/fzf#respecting-gitignore
