#!/bin/bash

USERNAME="sandip"

sudo pacman -S hyprland hyprpaper hyprpicker wl-clipboard xdg-desktop-portal-hyprland waybar hyprlock hypridle blueman rofi-wayland vlc ntfs-3g ffmpegthumbnailer alacritty xdg-user-dirs-gtk wget obs-studio qbittorrent starship dunst brightnessctl wlsunset grim slurp --noconfirm --needed

#GNOME APPS
sudo pacman -S nautilus rhythmbox evince loupe gnome-calendar gnome-shell gnome-calculator file-roller gnome-text-editor gvfs-mtp gnome-themes-extra adwaita-icon-theme --noconfirm --needed

#FONTS
sudo pacman -S noto-fonts noto-fonts-emoji noto-fonts-extra ttf-liberation noto-fonts-cjk ttf-dejavu ttf-font-awesome ttf-fira-sans ttf-jetbrains-mono --noconfirm --needed

cd scripts

sudo mkdir /etc/systemd/system/getty@tty1.service.d
sudo cp override.conf /etc/systemd/system/getty@tty1.service.d/override.conf
cp .zprofile /home/$USERNAME/.zprofile
sudo systemctl enable getty@tty1.service

sleep 3

sh aur.sh
sh battery.sh
sleep 3
sh ntfs.sh
sh zsh.sh
sh git.sh
sh gaming.sh
sh programs.sh

yay -S breezex-cursor-theme auto-cpufreq nautilus-open-any-terminal ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k google-chrome visual-studio-code-bin wlogout --noconfirm --needed
sudo auto-cpufreq --install
cd ..

cd config

rm -rf /home/$USERNAME/.config/*

cp -r * /home/$USERNAME/.config/

chmod +x /home/$USERNAME/.config/waybar/launch.sh
chmod +x /home/$USERNAME/.config/hypr/scripts/startvm.sh

cd ..

cd assets
cd icons
sudo cp * /usr/share/icons/hicolor/scalable/apps/

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

sudo cp Alacritty.desktop /usr/share/applications/Alacritty.desktop
sudo cp org.gnome.FileRoller.desktop /usr/share/applications/org.gnome.FileRoller.desktop

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal alacritty

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/sandip
sudo rm -r dotfiles
sudo rm -r yay

touch ~/Templates/NewDocument.txt
touch ~/Templates/File

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"
