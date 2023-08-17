#!/bin/bash

sudo pacman -S gnome-shell gnome-control-center gnome-calculator thunar thunar-archive-plugin tumbler gnome-tweaks gnome-terminal gnome-themes-extra evince eog gnome-text-editor file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch cmatrix gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer ttf-liberation noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"

#bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

##New file context menu
touch ~/Templates/NewDocument.txt

sh aur.sh

sudo systemctl enable gdm

exit