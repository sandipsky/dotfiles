#!/bin/bash

sudo apt purge gnome-contacts totem geary gnome-weather -y

#sublime text
#wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
#sudo apt-get install apt-transport-https
#echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

#spotify 
#curl -sS https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | sudo apt-key add - 
#echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

sudo apt update
sudo apt install gnome-tweaks vlc rhythmbox qbittorrent obs-studio visual-studio-code neofetch tlp tlp-rdw cmatrix -y

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"


sudo apt install python3-nautilus -y
bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

##New file context menu
touch ~/Templates/NewDocument.txt
touch ~/Templates/WordDocument.docx

sudo touch /etc/systemd/system/battery-charge-threshold.service
sudo bash -c "cat >> /etc/systemd/system/battery-charge-threshold.service" << EOF
[Unit]
Description=Set the battery charge threshold
After=multi-user.target

StartLimitBurst=0
[Service]
Type=oneshot
Restart=on-failure

ExecStart=/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold'
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable battery-charge-threshold.service
sudo systemctl enable tlp.service

