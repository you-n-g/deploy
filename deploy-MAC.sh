#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

deploy_apps/install_homebrew.sh
xcode-select --install

brew install --cask keyclu

brew install fnm


echo 'eval "$(fnm env --use-on-cd)"' >> ~/.zshrc  # mac has already use zsh as the default shell

brew install uv

# Common CLI tools (use brew instead of Linux-only install scripts).
brew install ripgrep fzf fd tmux lazygit

brew install gnupg # it takes very long time
brew install pinentry-mac
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf


bash ./configs/llm/conf_llm.sh

bash ./deploy_apps/install_zsh.sh

bash ./deploy_apps/config_git.sh

bash ./deploy_apps/nonauto/install_lazyvim.sh deploy_mac

bash deploy_apps/install_tmux.sh 
bash deploy_apps/install_pet.sh



# Optinal tools:
brew install htop

brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# 需要手动配置的 🙌
# 在 mac 默认终端 Terminal.app 里，<m-h> 对应的物理按键就是 ⌥ + h。
# 要让它真的变成 Vim/Neovim 里的 Meta（发送 Esc 前缀），需要在 Terminal.app 里把 Option 设为 Meta：
# - Terminal.app -> Settings(设置) -> Profiles(描述文件) -> Keyboard(键盘)
# - 勾选 Use Option as Meta key
#
# - Terminal.app -> Settings(设置) -> Profiles(描述文件) -> Text(文本)
# - 点 Change...（字体）
# - 选择刚装的 Nerd Font（例如 JetBrainsMono Nerd Font）

brew install orbstack
# 🙌 用lunchpad打开orbstack后，才能在bin中找到docker

brew install --cask sioyek
sudo xattr -rd com.apple.quarantine /Applications/sioyek.app  # otherwise it will be blocked by macOS


# Install WeChat
brew install --cask wechat


brew install koekeishiya/formulae/skhd
skhd --start-service
# Configure skhd to launch Obsidian with fn + 1
cat > ~/.skhdrc <<EOF
# fn + 1 launches Obsidian
fn - 1 : open -a Obsidian
EOF
skhd --restart-service
# If the hotkey still doesn't work:
# - System Settings -> Privacy & Security -> Accessibility -> enable for skhd
# - Check logs: /tmp/skhd_xiaoyang.err.log
