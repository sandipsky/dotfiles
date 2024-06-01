#!/bin/bash

#GNOME DESKTOP AND UTITLITIES
sudo pacman -S gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-software malcontent flatpak gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor xdg-user-dirs-gtk gdm gnome-keyring --noconfirm --needed

#FONTS
sudo pacman -S ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

#BASIC PROGRAMS
sudo pacman -S wget firefox vlc rhythmbox neofetch ntfs-3g tlp qbittorrent --noconfirm --needed

sudo systemctl enable gdm tlp

sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg

cd icons
sudo cp org.gnome.Software.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo cp org.gnome.Nautilus.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo cp org.gnome.Terminal.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg
sudo cp ms-excel.svg /usr/share/icons/hicolor/scalable/apps/ms-excel.svg
sudo cp ms-powerpoint.svg /usr/share/icons/hicolor/scalable/apps/ms-powerpoint.svg
sudo cp ms-word.svg /usr/share/icons/hicolor/scalable/apps/ms-word.svg

sudo rm /usr/share/applications/avahi-discover.desktop 
sudo rm /usr/share/applications/qv4l2.desktop 
sudo rm /usr/share/applications/qvidcap.desktop 
sudo rm /usr/share/applications/bvnc.desktop   
sudo rm /usr/share/applications/bssh.desktop 

touch ~/Templates/NewDocument.txt

cd ..
cd ..
cd scripts
sh aur.sh
sh ntfs.sh
sh battery.sh
sh programs.sh
sh zsh.sh

cd ..
cd gnome
cd extensions
sudo rm -r /usr/share/gnome-shell/extensions/* 
sudo cp -r * /usr/share/gnome-shell/extensions 

cd ..
cd keybindings
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf dump /org/gnome/desktop/wm/keybindings/ < wm  

sudo reboot


