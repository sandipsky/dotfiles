#!/bin/bash

USERNAME=$(logname)

cd /home/$USERNAME
sudo git clone https://aur.archlinux.org/yay.git
sudo chown -R $USERNAME:users yay
cd yay
makepkg -sri --needed --noconfirm
