#!/bin/bash

sudo auto-cpufreq --remove

sudo systemctl disable sddm

sudo pacman -Rnsc --noconfirm hyprland hyprpaper xdg-desktop-portal-hyprland waybar hyprlock hypridle blueman rhythmbox atril noto-fonts noto-fonts-emoji noto-fonts-extra rofi-wayland vlc firefox ntfs-3g tumbler ffmpegthumbnailer file-roller alacritty xdg-user-dirs-gtk neofetch mousepad gvfs-mtp galculator wget thunar thunar-archive-plugin noto-fonts noto-fonts-emoji ttf-dejavu ttf-font-awesome ttf-dejavu-nerd ttf-fira-sans starship dunst adwaita-icon-theme brightnessctl ttf-jetbrains-mono nwg-look sddm auto-cpufreq nomacs ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k

sudo pacman -Sc --noconfirm

rm -rf /home/sandip/.config/*
rm -rf /home/sandip/.local/bin/*

echo "Hyprland successfully uninstalled."