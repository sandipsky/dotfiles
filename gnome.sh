#!/bin/bash

USERNAME=$(logname)
FULLNAME=$(getent passwd "$USERNAME" | cut -d ':' -f 5 | cut -d ',' -f 1)
FULLNAME=${FULLNAME:-$USERNAME}

#GNOME DESKTOP AND UTITLITIES
sudo pacman -S gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince eog gnome-text-editor power-profiles-daemon xdg-user-dirs-gtk gdm gnome-keyring --noconfirm --needed

#FONTS
sudo pacman -S ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono ttf-dejavu noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

#BASIC PROGRAMS
sudo pacman -S wget vlc rhythmbox neofetch ntfs-3g qbittorrent switcheroo-control --noconfirm --needed

cd ..
cd scripts

sh aur.sh
sh battery.sh
sleep 3
sh ntfs.sh
sh zsh.sh
sh gaming.sh
sh programs.sh

yay -S breezex-cursor-theme google-chrome visual-studio-code-bin wlogout heidisql microsoft-edge-stable-bin --noconfirm --needed

cd ..
cd assets
cd icons
sudo cp * /usr/share/icons/hicolor/scalable/apps/

cd ..
cd mimetypes
sudo cp * /usr/share/icons/Adwaita/scalable/mimetypes/

cd ..
cd places
sudo cp * /usr/share/icons/Adwaita/scalable/places/

cd ..
cd apps
sudo rm /usr/share/applications/avahi-discover.desktop
sudo rm /usr/share/applications/blueman-adapters.desktop
sudo rm /usr/share/applications/blueman-manager.desktop
sudo rm /usr/share/applications/bssh.desktop
sudo rm /usr/share/applications/bvnc.desktop
sudo rm /usr/share/applications/rofi.desktop
sudo rm /usr/share/applications/rofi-theme-selector.desktop
sudo rm /usr/share/applications/qv4l2.desktop
sudo rm /usr/share/applications/qvidcap.desktop
sudo rm /usr/share/applications/Alacritty.desktop
sudo rm /usr/share/applications/cmake-gui.desktop
sudo rm /usr/share/applications/lstopo.desktop
sudo rm /usr/share/applications/java-java17-openjdk.desktop
sudo rm /usr/share/applications/jconsole-java17-openjdk.desktop
sudo rm /usr/share/applications/jshell-java17-openjdk.desktop
sudo rm /usr/share/applications/assistant.desktop
sudo rm /usr/share/applications/designer.desktop
sudo rm /usr/share/applications/linguist.desktop
sudo rm /usr/share/applications/qdbusviewer.desktop
sudo rm /usr/share/applications/auto-cpufreq-gtk.desktop
sudo rm /usr/share/applications/xgpsspeed.desktop
sudo rm /usr/share/applications/xgps.desktop

sudo cp * /usr/share/applications/

cd ..
cd keybindings
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf load /org/gnome/desktop/wm/keybindings/ < wm 

sudo rm -r /usr/share/gnome-shell/extensions/*
sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules
sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal alacritty

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/$USERNAME
sudo rm -r dotfiles
sudo rm -r yay

mkdir -p /home/$USERNAME/Templates
touch /home/$USERNAME/Templates/NewDocument.txt
touch /home/$USERNAME/Templates/File

sudo systemctl enable gdm switcheroo-control power-profiles-daemon

sudo reboot


