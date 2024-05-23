#!/bin/bash

sudo pacman -S nomacs blueman tlp network-manager-applet zsh zsh-syntax-highlighting zsh-autosuggestions rhythmbox atril noto-fonts noto-fonts-emoji noto-fonts-extra rofi vlc firefox ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller xfce4 xfce4-whiskermenu-plugin xfce4-battery-plugin xfce4-datetime-plugin xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-screensaver xfce4-notifyd lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty picom git xdg-user-dirs xdg-user-dirs-gtk neofetch cmatrix mousepad gvfs-mtp galculator wget thunar-archive-plugin noto-fonts noto-fonts-emoji ttf-dejavu ttf-dejavu-nerd libreoffice-fresh --noconfirm --needed

cd config

chmod 755 bspwm/bspwmrc
chmod 644 sxhkd/sxhkdrc

mkdir /home/sandip/.config
mkdir /home/sandip/.config/picom
mkdir /home/sandip/.config/bspwm
mkdir /home/sandip/.config/sxhkd
mkdir /home/sandip/.config/alacritty
mkdir /home/sandip/.config/rofi
mkdir /home/sandip/.fonts
mkdir /home/sandip/.icons
mkdir /home/sandip/.themes

cp picom/picom.conf /home/sandip/.config/picom/picom.conf
cp alacritty/alacritty.yml /home/sandip/.config/alacritty/alacritty.yml
cp bspwm/bspwmrc /home/sandip/.config/bspwm/bspwmrc
cp sxhkd/sxhkdrc /home/sandip/.config/sxhkd/sxhkdrc
cp rofi/* /home/sandip/.config/rofi/

cd ..

rm rf /home/sandip/.bashrc
cp .zshrc /home/sandip
cp .zprofile /home/sandip

cd fonts 
sudo cp -r * /home/sandip/.fonts

cd ..

sh aur.sh
sh ntfs.sh
sh battery.sh

sudo systemctl enable lightdm tlp
chsh -s /bin/zsh sandip










