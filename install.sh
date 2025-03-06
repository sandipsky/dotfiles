#!/bin/bash

USERNAME="sandip"

sudo pacman -S hyprland hyprpaper xdg-desktop-portal-hyprland waybar hyprlock hypridle blueman rhythmbox atril rofi-wayland vlc ntfs-3g tumbler ffmpegthumbnailer file-roller alacritty xdg-user-dirs-gtk neofetch mousepad gvfs-mtp wget thunar obs-studio qbittorrent thunar-archive-plugin noto-fonts noto-fonts-emoji noto-fonts-extra ttf-liberation noto-fonts-cjk ttf-dejavu ttf-font-awesome ttf-fira-sans starship dunst adwaita-icon-theme brightnessctl ttf-jetbrains-mono gnome-themes-extra wlsunset grim slurp sddm --noconfirm --needed

cd scripts

sh aur.sh
sh battery.sh
sleep 3
sh ntfs.sh
sh zsh.sh
sh git.sh
sh gaming.sh
sh programs.sh

yay -S nomacs ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k google-chrome visual-studio-code-bin wlogout --noconfirm --needed

cd ..

cd config

rm -rf /home/$USERNAME/.config/*

cp -r alacritty /home/$USERNAME/.config/
cp -r hypr /home/$USERNAME/.config/
cp -r rofi /home/$USERNAME/.config/
cp -r Thunar /home/$USERNAME/.config/
cp -r waybar /home/$USERNAME/.config/
cp -r dunst /home/$USERNAME/.config/

chmod +x /home/$USERNAME/.config/waybar/launch.sh

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
sudo rm /usr/share/applications/thunar-bulk-rename.desktop
sudo rm /usr/share/applications/thunar-settings.desktop
sudo rm /usr/share/applications/qv4l2.desktop
sudo rm /usr/share/applications/qvidcap.desktop
sudo rm /usr/share/applications/mate-color-select.desktop
sudo rm /usr/share/applications/xfce4-about.desktop
sudo rm /usr/share/applications/org.xfce.mousepad-settings.desktop
sudo rm /usr/share/applications/Alacritty.desktop
sudo rm /usr/share/applications/atril.desktop
sudo rm /usr/share/applications/org.nomacs.ImageLounge.desktop
sudo rm /usr/share/applications/org.xfce.mousepad.desktop
sudo rm /usr/share/applications/thunar.desktop
sudo rm /usr/share/applications/cmake-gui.desktop
sudo rm /usr/share/applications/lstopo.desktop
sudo rm /usr/share/applications/java-java21-openjdk.desktop
sudo rm /usr/share/applications/jconsole-java21-openjdk.desktop
sudo rm /usr/share/applications/jshell-java21-openjdk.desktop
sudo rm /usr/share/applications/code.desktop
sudo rm /usr/share/applications/google-chrome.desktop
sudo rm /usr/share/applications/assistant.desktop
sudo rm /usr/share/applications/designer.desktop
sudo rm /usr/share/applications/linguist.desktop
sudo rm /usr/share/applications/qdbusviewer.desktop

sudo cp Alacritty.desktop /usr/share/applications/Alacritty.desktop
sudo cp atril.desktop /usr/share/applications/atril.desktop
sudo cp org.nomacs.ImageLounge.desktop /usr/share/applications/org.nomacs.ImageLounge.desktop
sudo cp thunar.desktop /usr/share/applications/thunar.desktop
sudo cp org.gnome.FileRoller.desktop /usr/share/applications/org.gnome.FileRoller.desktop
sudo cp org.xfce.mousepad.desktop /usr/share/applications/org.xfce.mousepad.desktop
sudo cp code.desktop /usr/share/applications/code.desktop
sudo cp google-chrome.desktop /usr/share/applications/google-chrome.desktop

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/sandip
sudo rm -r dotfiles
sudo rm -r yay
