#!/bin/bash

#GNOME DESKTOP AND UTITLITIES
sudo pacman -S gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions papers loupe gnome-text-editor power-profiles-daemon xdg-user-dirs-gtk gdm gnome-keyring --noconfirm --needed

#FONTS
sudo pacman -S ttf-liberation noto-fonts-cjk otf-fira-sans ttf-jetbrains-mono ttf-dejavu noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

#BASIC PROGRAMS
sudo pacman -S wget vlc decibels gnome-music neofetch ntfs-3g qbittorrent switcheroo-control --noconfirm --needed

sudo systemctl enable gdm switcheroo-control 
sleep 3
touch ~/Templates/NewDocument.txt

cd keybindings
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf load /org/gnome/desktop/wm/keybindings/ < wm 

cd .. #gnome
cd .. #dotfiles
cd scripts
sh aur.sh
sh git.sh
sh ntfs.sh
sh automount.sh
sh battery.sh
sleep 4
sh programs.sh
sh gaming.sh

yay -S google-chrome visual-studio-code-bin extension-manager gdm-settings --noconfirm --needed

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
sudo rm /usr/share/applications/java-java17-openjdk.desktop
sudo rm /usr/share/applications/jconsole-java17-openjdk.desktop
sudo rm /usr/share/applications/jshell-java17-openjdk.desktop
sudo rm /usr/share/applications/code.desktop
sudo rm /usr/share/applications/google-chrome.desktop

cd ..
cd assets
cd icons
sudo cp org.gnome.Software.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo cp org.gnome.Nautilus.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo cp org.gnome.Terminal.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg

cd ..
cd apps
sudo cp code.desktop /usr/share/applications/code.desktop
sudo cp google-chrome.desktop /usr/share/applications/google-chrome.desktop

sudo rm -r /usr/share/gnome-shell/extensions/*
sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/sandip
sudo rm -r dotfiles
sudo rm -r yay

sudo reboot


