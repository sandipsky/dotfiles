#!/bin/bash

sudo pacman -S blueman network-manager-applet zsh zsh-syntax-highlighting zsh-autosuggestions rhythmbox atril noto-fonts noto-fonts-emoji noto-fonts-extra rofi vlc firefox ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller thunar lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty picom xdg-user-dirs-gtk neofetch mousepad gvfs-mtp galculator wget thunar-archive-plugin noto-fonts noto-fonts-emoji ttf-liberation ttf-dejavu ttf-jetbrains-mono ttf-fira-sans ttf-dejavu-nerd ttf-font-awesome polybar libadwaita nwg-look --noconfirm --needed

cd config

chmod 755 bspwm/bspwmrc
chmod 644 sxhkd/sxhkdrc

mkdir /home/sandip/.config
mkdir /home/sandip/.config/picom
mkdir /home/sandip/.config/bspwm
mkdir /home/sandip/.config/sxhkd
mkdir /home/sandip/.config/alacritty
mkdir /home/sandip/.config/rofi

cp picom/picom.conf /home/sandip/.config/picom/picom.conf
cp alacritty/alacritty.yml /home/sandip/.config/alacritty/alacritty.yml
cp bspwm/bspwmrc /home/sandip/.config/bspwm/bspwmrc
cp sxhkd/sxhkdrc /home/sandip/.config/sxhkd/sxhkdrc
cp rofi/* /home/sandip/.config/rofi/

cd ..

cd themes 
sudo cp -r * /usr/share/themes/

sudo systemctl enable lightdm 
chsh -s /bin/zsh sandip










