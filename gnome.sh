#!/bin/bash
sudo pacman -S xorg-server xorg-server-xwayland xorg-xinit xf86-input-libinput mesa pipewire pipewire-pulse pipewire-alsa nvidia nvidia-utils nvidia-settings nvidia-prime switcheroo-control --noconfirm --needed

sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions gnome-shell gnome-control-center gnome-calculator nautilus python-nautilus gnome-tweaks gnome-terminal gnome-themes-extra evince loupe gnome-text-editor file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer xdg-desktop-portal-gnome ttf-liberation noto-fonts noto-fonts-emoji noto-fonts-extra gnome-system-monitor gnome-software gnome-software-packagekit-plugin gnome-color-manager gnome-characters gnome-backgrounds gnome-font-viewer gnome-disk-utility gnome-screenshot archlinux-appstream-data gnome-shell-extensions sushi power-profiles-daemon --noconfirm --needed

curl -sS https://starship.rs/install.sh | sh

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"


gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'
gsettings set org.gnome.shell.extensions.dash-to-dock disable-overview-on-startup true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 5500

##New file context menu
touch ~/Templates/NewDocument.txt

sudo -s /dev/null /etc/udev/rules.d/61-gdm.rules

sh aur.sh
sh ntfs.sh
sh battery.sh

rm rf /home/sandip/.bashrc
cp .zshrc /home/sandip
cp .zprofile /home/sandip

sudo systemctl enable gdm switcheroo-control
sudo systemctl enable --user pipewire
sudo chsh -s /bin/zsh

sudo pacman -S Rnsc malcontent -y

