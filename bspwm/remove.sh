#!/bin/bash

sudo auto-cpufreq --remove

sudo systemctl disable lightdm
sudo systemctl disable betterlockscreen@sandip

sudo pacman -Rnsc --noconfirm blueman zsh zsh-syntax-highlighting zsh-autosuggestions redshift rhythmbox atril noto-fonts noto-fonts-emoji noto-fonts-extra rofi vlc ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller thunar lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty xdg-user-dirs-gtk neofetch mousepad gvfs-mtp galculator wget thunar-archive-plugin noto-fonts noto-fonts-emoji ttf-liberation ttf-dejavu ttf-jetbrains-mono ttf-fira-sans ttf-dejavu-nerd ttf-font-awesome polybar adwaita-icon-theme nwg-look brightnessctl dunst redshift auto-cpufreq picom-ftlabs-git betterlockscreen nomacs ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k google-chrome visual-studio-code-bin

sudo pacman -Sc --noconfirm

rm -rf /home/sandip/.config/*
rm -rf /home/sandip/.local/bin/*

echo "BSPWM successfully uninstalled."