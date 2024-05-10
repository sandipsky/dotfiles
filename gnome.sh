#!/bin/bash
sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions gnome-shell gnome-control-center gnome-calculator colord-gtk nautilus python-nautilus gnome-tweaks gnome-software malcontent flatpak gnome-terminal gnome-themes-extra evince loupe gnome-text-editor file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer xdg-desktop-portal-gnome ttf-liberation noto-fonts noto-fonts-emoji noto-fonts-extra gnome-system-monitor gnome-color-manager gnome-characters gnome-backgrounds gnome-font-viewer gnome-disk-utility gnome-screenshot gnome-shell-extensions power-profiles-daemon switcheroo-control --noconfirm --needed

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"

sh aur.sh
sh ntfs.sh

sudo systemctl enable gdm switcheroo-control


