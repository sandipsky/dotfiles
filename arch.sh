#!/bin/bash

sudo pacman -S ueberzug graphicsmagick ghostscript -y
cd .local
cd bin
chmod 755 lfub
mkdir /home/sandip/.local
mkdir /home/sandip/.local/bin
cp lfub /home/sandip/.local/bin

cd ..
cd ..

rm rf ~/.bashrc
cp .bashrc ~/.bashrc

cd ..

curl -sS https://starship.rs/install.sh | sh


#sudo su -c "echo '/dev/nvme0n1p3 /media/sandipsky ntfs nls-utf8,umask-0755,uid-1000,gid-1000,rw 0 0' >> /etc/fstab"



sudo cp 90-touchpad.conf /etc/X11/xorg.conf.d/90-touchpad.conf



#AUR
cd ~

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -sri

cd ~
rm -rf yay

yay -S visual-studio-code-bin lf-bin shell-color-scripts






