#!/bin/bash

sudo pacman -S gnome-shell gnome-control-center gnome-calendar gnome-calculator nautilus gnome-system-monitor gnome-tweaks gnome-screenshot gnome-terminal gnome-shell-extensions evince eog gedit file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch cmatrix gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer ttf-fira-sans noto-fonts noto-fonts-emoji --noconfirm --needed

yay -S visual-studio-code-bin plata-theme-bin brave-bin --needed --noconfirm

sudo systemctl enable gdm

exit