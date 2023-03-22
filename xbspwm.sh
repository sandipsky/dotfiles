#!/bin/bash


sudo pacman -S nomacs zsh zsh-syntax-highlighting zsh-autosuggestions rhythmbox atril firefox ttf-liberation noto-fonts noto-fonts-emoji rofi vlc firefox ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller xfce4 xfce4-whiskermenu-plugin xfce4-battery-plugin xfce4-datetime-plugin xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-screensaver xfce4-notifyd lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty picom git xdg-user-dirs xdg-user-dirs-gtk neofetch cmatrix mousepad gvfs-mtp galculator wget thunar-archive-plugin ttf-fira-sans noto-fonts noto-fonts-emoji -y

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




