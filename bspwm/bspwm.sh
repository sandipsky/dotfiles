#!/bin/bash

sudo pacman -S blueman zsh zsh-syntax-highlighting zsh-autosuggestions redshift rhythmbox atril noto-fonts noto-fonts-emoji noto-fonts-extra rofi vlc ntfs-3g tumbler ffmpegthumbnailer nitrogen bspwm sxhkd file-roller thunar lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings alacritty xdg-user-dirs-gtk neofetch mousepad gvfs-mtp galculator wget thunar-archive-plugin noto-fonts noto-fonts-emoji ttf-liberation ttf-dejavu ttf-jetbrains-mono ttf-fira-sans ttf-dejavu-nerd ttf-font-awesome polybar adwaita-icon-theme nwg-look brightnessctl dunst redshift --noconfirm --needed

yay -S auto-cpufreq picom-ftlabs-git betterlockscreen nomacs ttf-material-design-icons-desktop-git ttf-meslo-nerd-font-powerlevel10k google-chrome visual-studio-code-bin --noconfirm --needed

cd config

chmod 755 bspwm/bspwmrc
chmod 644 sxhkd/sxhkdrc

mkdir /home/sandip/.config
mkdir /home/sandip/.config/picom
mkdir /home/sandip/.config/bspwm
mkdir /home/sandip/.config/sxhkd
mkdir /home/sandip/.config/alacritty
mkdir /home/sandip/.config/rofi
mkdir /home/sandip/.config/dunst

cp picom/picom.conf /home/sandip/.config/picom/picom.conf
cp alacritty/alacritty.yml /home/sandip/.config/alacritty/alacritty.yml
cp bspwm/bspwmrc /home/sandip/.config/bspwm/bspwmrc
cp sxhkd/sxhkdrc /home/sandip/.config/sxhkd/sxhkdrc
cp rofi/* /home/sandip/.config/rofi/

cd ..
cd local
cd bin 
mkdir /home/sandip/.local
mkdir /home/sandip/.local/bin
cp -r * /home/sandip/.local/bin
chmod +x /home/sandip/.local/bin/powermenu
chmod +x /home/sandip/.local/bin/rofi-wifi-menu.sh
chmod +x /home/sandip/.local/bin/bluetooth_status.sh
chmod +x /home/sandip/.local/bin/bluetooth_toggle.sh

cd ..
cd ..

cd themes 
sudo cp -r * /usr/share/themes/

cd ..
cd icons
sudo cp * /usr/share/icons/hicolor/scalable/apps/

sudo rm /usr/share/applications/avahi-discover.desktop
sudo rm /usr/share/applications/blueman-adapters.desktop
sudo rm /usr/share/applications/blueman-manager.desktop
sudo rm /usr/share/applications/bssh.desktop
sudo rm /usr/share/applications/bvnc.desktop
sudo rm /usr/share/applications/rofi.desktop
sudo rm /usr/share/applications/rofi-theme-selector.desktop
sudo rm /usr/share/applications/thunar-bulk-rename.desktop
sudo rm /usr/share/applications/thunar-settings.desktop
sudo rm /usr/share/applications/redshift.desktop
sudo rm /usr/share/applications/redshift-gtk.desktop
sudo rm /usr/share/applications/picom.desktop
sudo rm /usr/share/applications/qv4l2.desktop
sudo rm /usr/share/applications/qvidcap.desktop
sudo rm /usr/share/applications/mate-color-select.desktop
sudo rm /usr/share/applications/nm-connection-editor.desktop
sudo rm /usr/share/applications/xfce4-about.desktop
sudo rm /usr/share/applications/org.xfce.mousepad-settings.desktop

sudo rm /usr/share/applications/Alacritty.desktop
sudo rm /usr/share/applications/atril.desktop
sudo rm /usr/share/applications/galculator.desktop
sudo rm /usr/share/applications/nitrogen.desktop
sudo rm /usr/share/applications/ngw-look.desktop
sudo rm /usr/share/applications/org.nomacs.ImageLounge.desktop
sudo rm /usr/share/applications/org.xfce.mousepad.desktop
sudo rm /usr/share/applications/thunar.desktop
sudo rm /usr/share/applications/auto-cpufreq-gtk.desktop
sudo rm /usr/share/applications/cmake-gui.desktop
sudo rm /usr/share/applications/lstopo.desktop
sudo rm /usr/share/applications/lightdm-gtk-greeter-settings.desktop

cd ..
cd apps
sudo cp * /usr/share/applications/

cd ..
sudo cp 90-touchpad.conf /etc/X11/xorg.conf.d/90-touchpad.conf

cd .. 
cd scripts
sh aur.sh
sh battery.sh
sh ntfs.sh
sh zsh.sh

sudo auto-cpufreq --install
sudo systemctl enable betterlockscreen@sandip
sudo systemctl enable lightdm 










