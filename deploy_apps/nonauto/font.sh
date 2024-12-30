#!/bin/bash
FONT_PATH=~/.fonts/JetBrainsMono
mkdir -p $FONT_PATH
cd $FONT_PATH

wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip

unzip JetBrainsMono.zip
rm JetBrainsMono.zip

fc-cache -fv

# make sure the font is correctly installed
fc-list  | grep JetBrainsMono | grep Regular | grep -v NL | grep Mono
# JetBrainsMono Nerd Font
