
#!/bin/bash
sudo pacman -S wget gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus gnome-tweaks gnome-software malcontent flatpak gnome-terminal gnome-themes-extra evince loupe gnome-text-editor file-roller xdg-user-dirs-gtk firefox vlc rhythmbox neofetch gdm gnome-keyring ntfs-3g gvfs-mtp ffmpegthumbnailer xdg-desktop-portal-gnome ttf-liberation ttf-fira-sans noto-fonts noto-fonts-emoji noto-fonts-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions tlp switcheroo-control --noconfirm --needed

sudo systemctl enable gdm switcheroo-control tlp


sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo rm /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg

cd icons
sudo cp org.gnome.Software.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Software.svg
sudo cp org.gnome.Nautilus.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
sudo cp org.gnome.Terminal.svg /usr/share/icons/hicolor/scalable/apps/org.gnome.Terminal.svg
sudo cp ms-excel.svg /usr/share/icons/hicolor/scalable/apps/ms-excel.svg
sudo cp ms-powerpoint.svg /usr/share/icons/hicolor/scalable/apps/ms-powerpoint.svg
sudo cp ms-word.svg /usr/share/icons/hicolor/scalable/apps/ms-word.svg

sudo rm /usr/share/applications/avahi-discover.desktop 
sudo rm /usr/share/applications/qv4l2.desktop 
sudo rm /usr/share/applications/qvidcap.desktop 
sudo rm /usr/share/applications/bvnc.desktop   
sudo rm /usr/share/applications/bssh.desktop 

touch ~/Templates/NewDocument.txt

cd ..
cd scripts
sh aur.sh
sh ntfs.sh
sh programs.sh
sh zsh.sh

sudo reboot


