#!/bin/bash

sudo pacman -S xorg-server xorg-xinit xf86-input-synaptics xf86-input-libinput mesa nvidia nvidia-utils pulseaudio -y

sudo pacman -S nomacs zsh zsh-syntax-highlighting lxappearance zsh-autosuggestions rhythmbox atril firefox ttf-liberation noto-fonts noto-fonts-emoji rofi rofi-emoji vlc firefox ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller polybar dunst lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty picom git xdg-user-dirs xdg-user-dirs-gtk neofetch cmatrix mousepad gvfs-mtp galculator scrot xclip xdotool wget thunar-archive-plugin -y


cd .config

chmod 755 bspwm/bspwmrc
chmod 644 sxhkd/sxhkdrc
chmod 755 polybar/*

mkdir /home/sandip/.config
mkdir /home/sandip/.config/picom
mkdir /home/sandip/.config/bspwm
mkdir /home/sandip/.config/sxhkd
mkdir /home/sandip/.config/alacritty
mkdir /home/sandip/.config/lf
mkdir /home/sandip/.config/rofi
mkdir /home/sandip/.config/polybar

cp picom/picom.conf /home/sandip/.config/picom/picom.conf
cp alacritty/alacritty.yml /home/sandip/.config/alacritty/alacritty.yml
cp bspwm/bspwmrc /home/sandip/.config/bspwm/bspwmrc
cp sxhkd/sxhkdrc /home/sandip/.config/sxhkd/sxhkdrc
cp lf/* /home/sandip/.config/lf/
cp rofi/* /home/sandip/.config/rofi/
cp polybar/* /home/sandip/.config/polybar/


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

sudo pacman -S ueberzug graphicsmagick ghostscript -y
cd .local
cd bin
chmod 755 *
mkdir /home/sandip/.local
mkdir /home/sandip/.local/bin
cp * /home/sandip/.local/bin

cd ..
cd ..

rm rf ~/.bashrc
cp .bashrc ~/.bashrc
cp .zshrc ~/
cp .zprofile ~/
cd fonts 
sudo cp -r * /usr/share/fonts


curl -sS https://starship.rs/install.sh | sh


#sudo su -c "echo '/dev/nvme0n1p3 /media/sandipsky ntfs nls-utf8,umask-0755,uid-1000,gid-1000,rw 0 0' >> /etc/fstab"



sudo cp 90-touchpad.conf /etc/X11/xorg.conf.d/90-touchpad.conf


yay -S visual-studio-code-bin lf-bin shell-color-scripts

sudo systemctl enable lightdm

sudo systemctl start lightdm


