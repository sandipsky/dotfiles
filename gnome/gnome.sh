#!/bin/bash

#GNOME DESKTOP AND UTITLITIES
sudo pacman -S gnome-shell gnome-control-center gnome-calendar gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor power-profiles-daemon xdg-user-dirs-gtk gdm gnome-keyring --noconfirm --needed

#FONTS
sudo pacman -S ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono ttf-dejavu noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

#BASIC PROGRAMS
sudo pacman -S wget vlc decibels gnome-music ntfs-3g qbittorrent switcheroo-control --noconfirm --needed

sudo systemctl enable gdm switcheroo-control 
sleep 3
touch ~/Templates/NewDocument.txt

cd keybindings
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf load /org/gnome/desktop/wm/keybindings/ < wm 

cd ..
cd extensions
sudo rm -r /usr/share/gnome-shell/extensions/*
sudo mkdir -p /usr/share/gnome-shell/extensions
sudo cp -r * /usr/share/gnome-shell/extensions/
sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

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
sh zsh.sh

yay -S breezex-cursor-theme google-chrome visual-studio-code-bin extension-manager gdm-settings --noconfirm --needed

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

cd ..
cd assets
cd icons
sudo cp org.gnome.Nautilus.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo cp org.gnome.Terminal.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg

sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,close' 
gsettings set org.gnome.shell.extensions.dash-to-dock disable-overview-on-startup true

touch ~/Templates/NewDocument.txt
touch ~/Templates/File

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/sandip 
sudo rm -r dotfiles
sudo rm -r yay

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

sudo reboot


