#!/bin/bash

sudo auto-cpufreq --remove

sudo systemctl disable lightdm switcheroo-control

sudo pacman -Rnsc --noconfirm gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-software malcontent flatpak gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor xdg-user-dirs-gtk gdm gnome-keyring ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono noto-fonts noto-fonts-emoji noto-fonts-extra wget vlc rhythmbox neofetch ntfs-3g qbittorrent switcheroo-control auto-cpufreq google-chrome visual-studio-code-bin 

sudo pacman -Sc --noconfirm

rm -rf /home/sandip/.config/*
rm -rf /home/sandip/.local/bin/*

echo "Gnome successfully uninstalled."