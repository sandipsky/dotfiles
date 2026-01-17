#!/bin/bash

USERNAME=$(logname)
FULLNAME=$(getent passwd "$USERNAME" | cut -d ':' -f 5 | cut -d ',' -f 1)
FULLNAME=${FULLNAME:-$USERNAME}

echo "Installing core packages..."
if ! sudo pacman -S gnome-shell gnome-control-center gnome-calculator extension-manager gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor power-profiles-daemon xdg-user-dirs-gtk gdm gnome-keyring ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono ttf-dejavu noto-fonts noto-fonts-emoji noto-fonts-extra wget vlc neofetch ntfs-3g qbittorrent switcheroo-control --noconfirm --needed; then
    echo "Pacman package installation failed. Aborting."
    exit 1
fi

cd scripts

sh aur.sh
sh battery.sh
sleep 2
sh ntfs.sh
sh gaming.sh
sh programs.sh

yay -S google-chrome visual-studio-code-bin neofetch --noconfirm --needed

cd ..
cd assets
cd gnome

dconf load /org/gnome/nautilus/ < nautilus
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < custom 
dconf load /org/gnome/desktop/wm/keybindings/ < wm 

sudo rm /usr/share/applications/avahi-discover.desktop
sudo rm /usr/share/applications/blueman-adapters.desktop
sudo rm /usr/share/applications/blueman-manager.desktop
sudo rm /usr/share/applications/bssh.desktop
sudo rm /usr/share/applications/bvnc.desktop
sudo rm /usr/share/applications/qv4l2.desktop
sudo rm /usr/share/applications/qvidcap.desktop
sudo rm /usr/share/applications/cmake-gui.desktop
sudo rm /usr/share/applications/lstopo.desktop
sudo rm /usr/share/applications/java-java21-openjdk.desktop
sudo rm /usr/share/applications/jconsole-java21-openjdk.desktop
sudo rm /usr/share/applications/jshell-java21-openjdk.desktop
sudo rm /usr/share/applications/assistant.desktop
sudo rm /usr/share/applications/designer.desktop
sudo rm /usr/share/applications/linguist.desktop
sudo rm /usr/share/applications/qdbusviewer.desktop
sudo rm /usr/share/applications/xgpsspeed.desktop
sudo rm /usr/share/applications/xgps.desktop
sudo rm /usr/share/applications/vim.desktop

sudo rm -r /usr/share/gnome-shell/extensions/*
sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.privacy remember-recent-files false

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/$USERNAME
sudo rm -rf dotfiles yay go

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

mkdir -p /home/$USERNAME/.config/gtk-3.0
cat > /home/$USERNAME/.config/gtk-3.0/bookmarks <<EOF
file:///home/$USERNAME/Documents Documents
file:///home/$USERNAME/Downloads Downloads
file:///home/$USERNAME/Music Music
file:///home/$USERNAME/Pictures Pictures
file:///home/$USERNAME/Videos Videos
EOF

sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
xdg-user-dirs-update
sudo systemctl enable --now gdm switcheroo-control