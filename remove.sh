#!/bin/bash

USERNAME="sandip"

chsh -s /bin/bash $USERNAME
sudo systemctl disable sddm

sleep 2

sudo pacman -Rnsc hyprland hyprpaper xdg-desktop-portal-hyprland waybar hyprlock hypridle atril rofi-wayland tumbler ffmpegthumbnailer file-roller alacritty xdg-user-dirs-gtk neofetch mousepad gvfs-mtp wget thunar thunar-archive-plugin dunst adwaita-icon-theme brightnessctl gnome-themes-extra wlsunset grim slurp sddm nomacs zsh zsh-syntax-highlighting zsh-autosuggestions --noconfirm


rm -rf /home/$USERNAME/.config/alacritty
rm -rf /home/$USERNAME/.config/hypr
rm -rf /home/$USERNAME/.config/rofi
rm -rf /home/$USERNAME/.config/Thunar
rm -rf /home/$USERNAME/.config/waybar
rm -rf /home/$USERNAME/.config/dunst
rm /home/$USERNAME/.zshrc
