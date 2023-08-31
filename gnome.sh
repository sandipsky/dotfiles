#!/bin/bash
sudo pacman -S xorg-server xorg-server-xwayland xorg-xinit xf86-input-libinput mesa pipewire pipewire-pulse pipewire-alsa --noconfirm --needed
sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions touchegg gnome-shell gnome-control-center gnome-calculator nautilus python-nautilus gnome-tweaks gnome-terminal gnome-themes-extra evince eog gnome-text-editor file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch cmatrix gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer ttf-liberation noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

curl -sS https://starship.rs/install.sh | sh

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"


gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

##New file context menu
touch ~/Templates/NewDocument.txt

sh aur.sh
sh ntfs.sh
sh battery.sh

rm rf /home/sandip/.bashrc
cp .bashrc /home/sandip/.bashrc
cp .zshrc /home/sandip
cp .zprofile /home/sandip

sudo systemctl enable gdm
sudo systemctl enable touchegg.service
sudo chsh -s /bin/zsh

