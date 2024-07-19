#!/bin/bash

sudo pacman -S hyprland hyprpaper xdg-desktop-portal-hyprland waybar hyprlock hypridle blueman rhythmbox atril rofi-wayland vlc ntfs-3g tumbler ffmpegthumbnailer file-roller alacritty xdg-user-dirs-gtk neofetch mousepad gvfs-mtp wget thunar thunar-archive-plugin noto-fonts noto-fonts-emoji noto-fonts-extra ttf-liberation noto-fonts-cjk ttf-dejavu ttf-font-awesome ttf-fira-sans starship dunst adwaita-icon-theme brightnessctl ttf-jetbrains-mono nwg-look gnome-themes-extra wlsunset grim slurp --noconfirm --needed

cd .. 
cd scripts
sh aur.sh
sh battery.sh
sh ntfs.sh
sh zsh.sh

yay -S auto-cpufreq nomacs ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k google-chrome visual-studio-code-bin wlogout --noconfirm --needed
sudo auto-cpufreq --install

sudo mkdir /etc/systemd/system/getty@tty1.service.d
sudo cp override.conf /etc/systemd/system/getty@tty1.service.d/override.conf
sudo systemctl enable getty@tty1.service

cp .zprofile /home/sandip/.zprofile
cd ..

cd config
rm -rf /home/sandip/.config/*
cp -r * /home/sandip/.config/
chmod +x /home/sandip/.config/waybar/launch.sh
cd ..

cd assets
cd icons
sudo cp * /usr/share/icons/hicolor/scalable/apps/
cd ..

sudo rm /usr/share/applications/avahi-discover.desktop
sudo rm /usr/share/applications/blueman-adapters.desktop
sudo rm /usr/share/applications/blueman-manager.desktop
sudo rm /usr/share/applications/bssh.desktop
sudo rm /usr/share/applications/bvnc.desktop
sudo rm /usr/share/applications/rofi.desktop
sudo rm /usr/share/applications/rofi-theme-selector.desktop
sudo rm /usr/share/applications/thunar-bulk-rename.desktop
sudo rm /usr/share/applications/thunar-settings.desktop
sudo rm /usr/share/applications/picom.desktop
sudo rm /usr/share/applications/qv4l2.desktop
sudo rm /usr/share/applications/qvidcap.desktop
sudo rm /usr/share/applications/nm-connection-editor.desktop
sudo rm /usr/share/applications/mate-color-select.desktop
sudo rm /usr/share/applications/xfce4-about.desktop
sudo rm /usr/share/applications/org.xfce.mousepad-settings.desktop
sudo rm /usr/share/applications/Alacritty.desktop
sudo rm /usr/share/applications/atril.desktop
sudo rm /usr/share/applications/ngw-look.desktop
sudo rm /usr/share/applications/org.nomacs.ImageLounge.desktop
sudo rm /usr/share/applications/org.xfce.mousepad.desktop
sudo rm /usr/share/applications/thunar.desktop
sudo rm /usr/share/applications/auto-cpufreq-gtk.desktop
sudo rm /usr/share/applications/cmake-gui.desktop
sudo rm /usr/share/applications/lstopo.desktop
cd apps
sudo cp Alacritty.desktop /usr/share/applications/Alacritty.desktop
sudo cp atril.desktop /usr/share/applications/atril.desktop
sudo cp org.nomacs.ImageLounge.desktop /usr/share/applications/org.nomacs.ImageLounge.desktop



