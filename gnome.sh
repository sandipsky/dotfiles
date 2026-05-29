#!/bin/bash
set -e

USERNAME=$(logname)

sudo pacman -S --noconfirm --needed \
    gnome \
    gnome-tweaks \
    gdm \
    nautilus \
    gnome-text-editor \
    gnome-calculator \
    evince \
    loupe \
    file-roller \
    gvfs-mtp \
    gnome-themes-extra \
    adwaita-icon-theme \
    xdg-user-dirs-gtk \
    wl-clipboard \
    blueman \
    jq \
    alacritty \
    obs-studio \
    qbittorrent \
    brightnessctl \
    libreoffice-fresh

yay -S --noconfirm --needed \
    breezex-cursor-theme

sudo mkdir -p /usr/share/sounds/
sudo cp assets/sounds/* /usr/share/sounds/

sudo mkdir -p /usr/share/fonts
sudo cp assets/fonts/* /usr/share/fonts/
sudo fc-cache -f

sudo systemctl enable gdm.service

sudo -u "$USERNAME" -H dbus-run-session -- bash <<'EOF'
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
EOF

sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/jpeg
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/png
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/webp

sudo -u "$USERNAME" -H xdg-mime default org.gnome.TextEditor.desktop text/plain
sudo -u "$USERNAME" -H xdg-mime default org.gnome.TextEditor.desktop application/x-shellscript

sudo -u "$USERNAME" -H xdg-user-dirs-update

reboot
