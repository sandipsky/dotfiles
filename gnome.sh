#!/bin/bash
sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions gnome-shell gnome-control-center gnome-calculator nautilus python-nautilus gnome-tweaks gnome-terminal gnome-themes-extra evince loupe gnome-text-editor file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer xdg-desktop-portal-gnome ttf-liberation noto-fonts noto-fonts-emoji noto-fonts-extra gnome-system-monitor gnome-color-manager gnome-characters gnome-backgrounds gnome-font-viewer gnome-disk-utility gnome-screenshot gnome-shell-extensions power-profiles-daemon switcheroo-control --noconfirm --needed

curl -sS https://starship.rs/install.sh | sh

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"


gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'
gsettings set org.gnome.shell.extensions.dash-to-dock disable-overview-on-startup true

##New file context menu
touch ~/Templates/NewDocument.txt

sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

sh aur.sh
sh ntfs.sh

sudo systemctl enable gdm switcheroo-control


