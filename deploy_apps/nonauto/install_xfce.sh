#!/bin/sh

if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    exit
fi

sudo apt-get update

sudo apt install -y xfce4 xfce4-goodies tightvncserver



# 可以跑 



mkdir -p  ~/.vnc

cat <<"EOF"  > ~/.vnc/xstartup
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# exec /etc/X11/xinit/xinitrc
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &

x-terminal-emulator -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &
#x-window-manager &
#gnome-session &
x-session-manager & xfdesktop & xfce4-panel &
xfce4-menu-plugin &
xfsettingsd &
xfconfd &
xfwm4 &
EOF


chmod +x ~/.vnc/xstartup


echo 'please run `vncserver` to start. 这里会提示设置两个密码'
echo '用这个命令把端口转发到本地 `ssh -L 5901:127.0.0.1:5901 -N -f username@server_ip_address`'
# TODO:
# -f
echo '- 用vnc登录到本地 127.0.0.1 不需要密码'



# 有用的命令
# vncserver -kill :1 
# vncserver -geometry 1600x1200 # -randr 1600x1200,1440x900,1024x768
# export DISPLAY=:1

# ref
# 本教程参考了: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-16-04
