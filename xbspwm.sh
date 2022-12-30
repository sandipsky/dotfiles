#!/bin/bash


sudo pacman -S nomacs zsh zsh-syntax-highlighting zsh-autosuggestions rhythmbox atril firefox ttf-liberation noto-fonts noto-fonts-emoji rofi vlc firefox ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller xfce4 xfce4-whiskermenu-plugin xfce4-battery-plugin xfce4-datetime-plugin xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-screensaver xfce4-notifyd lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty picom git xdg-user-dirs xdg-user-dirs-gtk neofetch cmatrix mousepad gvfs-mtp galculator wget thunar-archive-plugin -y


cd .config

chmod 755 bspwm/bspwmrc
chmod 644 sxhkd/sxhkdrc

mkdir /home/sandip/.config
mkdir /home/sandip/.config/picom
mkdir /home/sandip/.config/bspwm
mkdir /home/sandip/.config/sxhkd
mkdir /home/sandip/.config/alacritty
mkdir /home/sandip/.config/lf
mkdir /home/sandip/.config/rofi

cp picom/picom.conf /home/sandip/.config/picom/picom.conf
cp alacritty/alacritty.yml /home/sandip/.config/alacritty/alacritty.yml
cp bspwm/bspwmrc /home/sandip/.config/bspwm/bspwmrc
cp sxhkd/sxhkdrc /home/sandip/.config/sxhkd/sxhkdrc
cp lf/* /home/sandip/.config/lf/
cp rofi/* /home/sandip/.config/rofi/

cd ..

#echo "Are you using Real Hardware?"

#read in

#if [ $in == 'y' ]
#then 
#    ./arch.sh
#else
#    echo "moving on"
#fi

#echo "Do U want Programming Tools?"

#read ni


sudo systemctl enable lightdm

sudo systemctl start lightdm


