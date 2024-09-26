#!/bin/bash
sudo pacman -S hyprland hyprpaper xdg-desktop-portal-hyprland waybar hyprlock hypridle blueman rhy>

cd ..
cd scripts
sh aur.sh
sh battery.sh
sh ntfs.sh
sh zsh.sh

yay -S auto-cpufreq nomacs ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k>
sudo auto-cpufreq --install

sudo mkdir /etc/systemd/system/getty@tty1.service.d
sudo cp override.conf /etc/systemd/system/getty@tty1.service.d/override.conf
sudo systemctl enable getty@tty1.service

cp .zprofile /home/sandip/.zprofile
cd ..

cd config
rm -rf /home/sandip/.config/*
cp -r * /home/sandip/.config/
chmod +x /home/sandip/.config/waybar/launch.sh
cd ..

cd assets
cd icons
sudo cp * /usr/share/icons/hicolor/scalable/apps/
cd ..

sudo rm /usr/share/applications/avahi-discover.desktop
sudo rm /usr/share/applications/blueman-adapters.desktop
