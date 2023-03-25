#!/bin/bash

sudo pacman -S plasma konsole sddm ark dolphin spectacle nomacs kalendar okular kcalc ffmpegthumbs xdg-user-dirs firefox vlc rhythmbox neofetch cmatrix ntfs-3g gvfs-mtp ffmpegthumbnailer noto-fonts noto-fonts-emoji ttf-fira-sans sddm --noconfirm --needed

yay -S visual-studio-code-bin brave-bin --needed --noconfirm

sudo systemctl enable sddm

exit