#!/bin/bash

#GNOME DESKTOP AND UTITLITIES
sudo pacman -S gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor xdg-user-dirs-gtk gdm gnome-keyring power-profiles-daemon --noconfirm --needed

#FONTS
sudo pacman -S ttf-liberation noto-fonts-cjk ttf-jetbrains-mono noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

#BASIC PROGRAMS
sudo pacman -S wget vlc rhythmbox neofetch ntfs-3g qbittorrent switcheroo-control --noconfirm --needed

sudo systemctl enable gdm switcheroo-control 

touch ~/Templates/NewDocument.txt

cd ..
cd ..
cd scripts
sh aur.sh
sh ntfs.sh
sh battery.sh
sh zsh.sh

yay -S google-chrome visual-studio-code-bin --noconfirm --needed

cd ..
cd keybindings
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf load /org/gnome/desktop/wm/keybindings/ < wm  

sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg

sudo rm /usr/share/applications/avahi-discover.desktop 
sudo rm /usr/share/applications/qv4l2.desktop 
sudo rm /usr/share/applications/qvidcap.desktop 
sudo rm /usr/share/applications/bvnc.desktop   
sudo rm /usr/share/applications/bssh.desktop 
sudo rm /usr/share/applications/lstopo.desktop
sudo rm /usr/share/applications/nm-connection-editor.desktop

cd ..
cd ..
cd assets
cd icons
sudo cp org.gnome.Software.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo cp org.gnome.Nautilus.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo cp org.gnome.Terminal.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg
sudo cp ms-excel.svg /usr/share/icons/hicolor/scalable/apps/ms-excel.svg
sudo cp ms-word.svg /usr/share/icons/hicolor/scalable/apps/ms-word.svg
sudo cp ms-powerpoint.svg /usr/share/icons/hicolor/scalable/apps/ms-powerpoint.svg


sudo reboot


