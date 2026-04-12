#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

SSH_FLAG=""
while getopts ":s" opt; do
    case $opt in
    s) SSH_FLAG="-s" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

deploy_apps/install_homebrew.sh
xcode-select --install

brew install --cask keyclu

brew install fnm


echo 'eval "$(fnm env --use-on-cd)"' >> ~/.zshrc  # mac has already use zsh as the default shell

brew install uv
uv tool install ranger-fm  # will brew be a better choice?
brew install bat

mkdir -p ~/.config/ranger
ln -sfn ~/deploy/configs/ranger/rc.conf ~/.config/ranger/rc.conf

# Common CLI tools (use brew instead of Linux-only install scripts).
brew install ripgrep fzf fd tmux lazygit
brew install iproute2mac # 

# bash ./deploy_apps/install_macos_ssh.sh

brew install gnupg # it takes very long time
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg
# NOTE: 我开多桌面后，有时候他会有问题（我想在弹出的框框里面输密码，结果东西都输入到终端里面了）
# brew install pinentry-mac
# echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
cat ~/deploy/configs/misc/gpg-agent.conf >> ~/.gnupg/gpg-agent.conf


bash ./configs/llm/conf_llm.sh

bash ./deploy_apps/install_zsh.sh

bash ./deploy_apps/config_git.sh

# clone repos (-s for SSH, required for private repos like farside)
bash ./deploy_apps/clone_repos.sh $SSH_FLAG

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
brew install cliclick
skhd --start-service
# Configure skhd to launch Obsidian with fn + 1
if [ -f ~/.skhdrc ]; then
  rm ~/.skhdrc
fi
ln -s ~/deploy/configs/skhdrc ~/.skhdrc
skhd --restart-service
# 🙌 If the hotkey still doesn't work:
# - System Settings -> Privacy & Security -> Accessibility -> enable for skhd
# - Check logs: /tmp/skhd_xiaoyang.err.log

brew install koekeishiya/formulae/yabai
yabai --start-service


brew install --cask xquartz
# 🙌 
# 1) 注销并重新登录：安装完成后，强烈建议你注销当前 macOS 用户并重新登录（或者直接重启）。这是因为 XQuartz 需要设置一些系统环境变量（如 $DISPLAY），这些变量在重新登录后才会对所有终端生效。
# 配置权限（针对 SSH 转发）：
# 2) 启动 XQuartz（在“应用程序”或 Spotlight 中搜索）。
# 点击顶部菜单栏的 XQuartz -> 设置 (Settings/Preferences)。
# 切换到 安全性 (Security) 选项卡。
# 勾选 "允许从网络客户端连接" (Allow connections from network clients)。
# 3) Sometimes, we need to restart the server


brew install --cask iterm2
# 🙌  
# Profile -> Text:  设置nerd font;  然后启动 ligature
#         -> Keys:  Left Option => Esc+


brew install --cask homerow
# 🙌
# 手动启动，开启相应权限，开机启动

brew install --cask zotero


# 🙌 其他手动操作的事情
# - battery -> options -> Prevent automatic sleeping ...
