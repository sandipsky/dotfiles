#!/bin/bash

sudo apt update
sudo apt install ./debget.deb -y
sudo apt install ./chrome.deb -y
sudo apt install eog lightdm-gtk-greeter-settings evince rhythmbox vlc mousepad vim grub-customizer dmenu nitrogen bspwm sxhkd picom tumbler ffmpegthumbnailer -y
deb-get install spotify-client 
deb-get install code 

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

sudo cat locale.txt > /etc/locale.gen
locale-gen

cat bash.txt >> /home/sandipsky/.bashrc

sudo apt -y install software-properties-common
sudo apt -y install software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo apt -y install php7.4
sudo apt-get install -y php7.4-cli php7.4-json php7.4-common php7.4-mysql php7.4-zip php7.4-gd php7.4-mbstring php7.4-curl php7.4-xml php7.4-bcmath

chmod 755 composer.phar
sudo cp composer.phar /usr/local/bin/composer

composer global require laravel/installer

sudo apt install python3-pip

pip3 install django pillow 

chmod +x xampp.run
sudo ./xampp.run
