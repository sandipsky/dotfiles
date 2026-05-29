#!/bin/bash
set -e

USERNAME=$(logname)

sudo pacman -S --noconfirm --needed \
    gnome-shell \
    gnome-session \
    gnome-control-center \
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
    gnome-terminal \
    obs-studio \
    qbittorrent \
    libreoffice-fresh \
    wl-clipboard \
    meson \
    ninja \
    gcc \
    pkgconf \
    desktop-file-utils \
    gstreamer \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-bad \
    gst-libav

yay -S --noconfirm --needed \
    breezex-cursor-theme

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

sudo -u "$USERNAME" -H xdg-user-dirs-update

# Build + install the GTK apps. All their build deps were installed above, so
# the installers won't need sudo.
sudo -u "$USERNAME" -H bash -c "cd '$PWD/applications/music' && echo Y | ./install.sh"
sudo -u "$USERNAME" -H bash -c "cd '$PWD/applications/launcher' && echo Y | ./install.sh"

reboot
