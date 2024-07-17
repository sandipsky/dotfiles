#!/bin/bash

#GNOME DESKTOP AND UTITLITIES
sudo pacman -S gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-software malcontent flatpak gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor xdg-user-dirs-gtk gdm gnome-keyring --noconfirm --needed

#FONTS
sudo pacman -S ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

#BASIC PROGRAMS
sudo pacman -S wget vlc rhythmbox neofetch ntfs-3g qbittorrent switcheroo-control --noconfirm --needed

sudo systemctl enable gdm switcheroo-control 

sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg

cd icons
sudo cp * /usr/share/icons/hicolor/scalable/apps/

sudo rm /usr/share/applications/avahi-discover.desktop 
sudo rm /usr/share/applications/qv4l2.desktop 
sudo rm /usr/share/applications/qvidcap.desktop 
sudo rm /usr/share/applications/bvnc.desktop   
sudo rm /usr/share/applications/bssh.desktop 
sudo rm /usr/share/applications/lstopo.desktop
sudo rm /usr/share/applications/nm-connection-editor.desktop

touch ~/Templates/NewDocument.txt

cd ..
cd ..
cd scripts
sh aur.sh
sh ntfs.sh
sh battery.sh
sh zsh.sh

yay -S auto-cpufreq google-chrome visual-studio-code-bin --noconfirm --needed
sudo auto-cpufreq --install

cd ..
cd gnome
cd extensions
sudo rm -r /usr/share/gnome-shell/extensions/* 
sudo cp -r * /usr/share/gnome-shell/extensions 

cd ..
cd keybindings
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf load /org/gnome/desktop/wm/keybindings/ < wm  

sudo reboot


