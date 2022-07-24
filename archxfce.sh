#!/bin/bash

sudo pacman -S eog rhythmbox vlc firefox git ntfs-3g tumbler ffmpegthumbnailer ttf-fira-sans noto-fonts noto-fonts-emoji  

mkdir /home/sandipsky/.config/picom
mkdir /home/sandipsky/.config/bspwm
mkdir /home/sandipsky/.config/sxhkd
cp .config/picom/picom.conf /home/sandipsky/.config/picom/picom.conf
chmod 755 .config/bspwm/bspwmrc
chmod 644 .config/sxhkd/sxhkdrc
cp .config/bspwm/bspwmrc /home/sandipsky/.config/bspwm/bspwmrc
cp .config/sxhkd/sxhkdrc /home/sandipsky/.config/sxhkd/sxhkdrc

curl -sS https://starship.rs/install.sh | sh

cd ..

sudo cp wall/* /usr/share/backgrounds
sudo cp -r themes/* /usr/share/themes
sudo cp -r icons/* /usr/share/icons
sudo cp -r fonts/* /usr/share/fonts/truetype

cat bash.txt >> /home/sandipsky/.bashrc

chmod 755 composer.phar
sudo cp composer.phar /usr/local/bin/composer

composer global require laravel/installer

pip install django pillow 

