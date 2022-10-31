#!/bin/bash


sudo pacman -S nomacs rhythmbox atril firefox vlc firefox ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller xfce4 xfce4-whiskermenu-plugin xfce4-battery-plugin xfce4-datetime-plugin xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-screensaver xfce4-notifyd lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty picom git xdg-user-dirs neofetch cmatrix mousepad gvfs-mtp galculator wget nemo nemo-fileroller -y

./ntfs.sh

cd .config

chmod 755 bspwm/bspwmrc
chmod 644 sxhkd/sxhkdrc

mkdir /home/sandipsky/.config
mkdir /home/sandipsky/.config/picom
mkdir /home/sandipsky/.config/bspwm
mkdir /home/sandipsky/.config/sxhkd
mkdir /home/sandipsky/.config/alacritty
mkdir /home/sandipsky/.config/lf
mkdir /home/sandipsky/.config/rofi

cp picom/picom.conf /home/sandipsky/.config/picom/picom.conf
cp alacritty/alacritty.yml /home/sandipsky/.config/alacritty/alacritty.yml
cp bspwm/bspwmrc /home/sandipsky/.config/bspwm/bspwmrc
cp sxhkd/sxhkdrc /home/sandipsky/.config/sxhkd/sxhkdrc
cp lf/* /home/sandipsky/.config/lf/
cp rofi/* /home/sandipsky/.config/rofi/

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


