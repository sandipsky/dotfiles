#!/bin/bash

USERNAME=$(logname)
FULLNAME=$(getent passwd "$USERNAME" | cut -d ':' -f 5 | cut -d ',' -f 1)
FULLNAME=${FULLNAME:-$USERNAME}

sudo pacman -S hyprland wpaperd hyprpicker wl-clipboard xdg-desktop-portal-hyprland waybar hyprlock hypridle blueman rofi-wayland vlc vlc-plugins-all ntfs-3g ffmpegthumbnailer alacritty xdg-user-dirs-gtk wget obs-studio qbittorrent starship dunst brightnessctl wlsunset grim slurp --noconfirm --needed

#GNOME APPS
sudo pacman -S power-profiles-daemon gnome-calculator nautilus rhythmbox evince loupe gnome-shell file-roller gnome-text-editor gvfs-mtp gnome-themes-extra adwaita-icon-theme --noconfirm --needed

#FONTS
sudo pacman -S noto-fonts noto-fonts-emoji noto-fonts-extra ttf-liberation noto-fonts-cjk ttf-dejavu otf-font-awesome ttf-fira-sans ttf-jetbrains-mono --noconfirm --needed

#sddm
sudo pacman -S sddm qt5-graphicaleffects qt5-base qt5-declarative --noconfirm --needed
sudo sed -i "s/^Current=.*/Current=Elegant/g" /usr/lib/sddm/sddm.conf.d/default.conf
sudo sed -i "s/^CursorTheme=.*/CursorTheme=BreezeX-Light/g" /usr/lib/sddm/sddm.conf.d/default.conf
cd assets
sudo cp sddm/.face.icon /usr/share/sddm/faces/
sudo cp -r sddm/themes/* /usr/share/sddm/themes/

# QML_FILE="/usr/share/sddm/themes/Elegant/LoginFrame.qml"
# sudo sed -i "s/^    property string userName:.*/    property string userName: \"$USERNAME\"/" "$QML_FILE"
# sudo sed -i "s/^    property string fullName:.*/    property string fullName: \"$FULLNAME\"/" "$QML_FILE"

cd ..
cd scripts

# sudo cp usb-insert.service /etc/systemd/system/usb-insert.service
# sudo cp usb-remove.service /etc/systemd/system/usb-remove.service
# sudo cp 90-usb.rules /etc/udev/rules.d/90-usb.rules
sudo cp acpoweron.service /etc/systemd/system/acpoweron.service
sudo cp acpoweroff.service /etc/systemd/system/acpoweroff.service
sudo cp 99-power.rules /etc/udev/rules.d/99-power.rules

sleep 3

sh aur.sh
sh battery.sh
sleep 3
sh ntfs.sh
sh zsh.sh
sh gaming.sh
sh programs.sh

yay -S breezex-cursor-theme ttf-material-design-icons-desktop-git nautilus-open-any-terminal google-chrome visual-studio-code-bin wlogout heidisql microsoft-edge-stable-bin --noconfirm --needed
cd ..

cd config

rm -rf /home/$USERNAME/.config/*

cp -r * /home/$USERNAME/.config/

chmod +x /home/$USERNAME/.config/waybar/launch.sh
chmod +x /home/$USERNAME/.config/hypr/scripts/startvm.sh

cd ..

cd assets
mkdir -p /home/$USERNAME/Pictures
sudo cp images/* -r /home/$USERNAME/Pictures/

cd sounds
sudo mkdir -p /usr/share/sounds/
sudo cp * /usr/share/sounds/

cd ..
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

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

sudo rm /usr/share/xsessions/*
sudo rm /usr/share/wayland-sessions/gnome.desktop
sudo rm /usr/share/wayland-sessions/gnome-wayland.desktop
sudo rm /usr/share/wayland-sessions/hyprland-uwsm.desktop

LOCK_FILE="/home/$USERNAME/.config/hypr/hyprlock.conf"
sed -i "s/^\s*text = FULLNAME/    text = $FULLNAME/" "$LOCK_FILE"

sudo systemctl enable sddm
sudo systemctl enable power-profiles-daemon
