#!/bin/bash

USERNAME=$(logname)
FULLNAME=$(getent passwd "$USERNAME" | cut -d ':' -f 5 | cut -d ',' -f 1)
FULLNAME=${FULLNAME:-$USERNAME}

echo "Installing core packages..."
if ! sudo pacman -S ark dolphin kio-admin kate konsole plasma-meta gwenview vlc vlc-plugins-all ntfs-3g ffmpegthumbnailer wget obs-studio qbittorrent qt5-graphicaleffects qt5-base qt5-declarative power-profiles-daemon gvfs-mtp noto-fonts noto-fonts-emoji noto-fonts-extra ttf-liberation noto-fonts-cjk ttf-dejavu ttf-fira-sans ttf-jetbrains-mono --noconfirm --needed; then
    echo "Pacman package installation failed. Aborting."
    exit 1
fi

cd scripts

sh aur.sh
sh battery.sh
sleep 2
sh ntfs.sh
sh zsh.sh
sh gaming.sh
sh programs.sh

yay -S google-chrome visual-studio-code-bin --noconfirm --needed
cd ..

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
sudo mount -a
cd /home/$USERNAME
sudo rm -rf dotfiles yay go

CONF_FILE="/etc/mkinitcpio.conf"
# Check if modules already exist
if grep -q "nvidia_drm" "$CONF_FILE"; then
    echo "NVIDIA modules already present in MODULES array. Skipping modification."
else
    echo "Adding NVIDIA modules to MODULES array..."
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$CONF_FILE"
    sudo sed -i 's/\<kms\>//g' "$CONF_FILE"
    sudo sed -i 's/  */ /g' "$CONF_FILE" 
fi

echo "Modifying HOOKS array..."
sudo sed -i -E 's/\budev\b/systemd/' "$CONF_FILE"
sudo sed -i -E 's/\s*fsck\b//g' "$CONF_FILE"

# Rebuild initramfs
echo "Rebuilding initramfs with mkinitcpio..."
sudo mkinitcpio -P

sudo systemctl enable sddm power-profiles-daemon
systemctl --user enable pipewire pipewire-pulse wireplumber 