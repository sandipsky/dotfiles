curl -sS https://starship.rs/install.sh | sh

##Workspace Keyboard
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super><Ctrl>Right']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super><Ctrl>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "[\"<Super><alt>Right\"]"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "[\"<Super><alt>Left\"]"

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"


gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'
gsettings set org.gnome.shell.extensions.dash-to-dock disable-overview-on-startup true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 5600

##New file context menu
touch ~/Templates/NewDocument.txt

sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

rm rf /home/sandip/.bashrc
cp .zshrc /home/sandip
cp .zprofile /home/sandip

chsh -s /bin/zsh sandip


