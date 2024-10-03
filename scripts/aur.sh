cd /home/sandip
sudo git clone https://aur.archlinux.org/yay.git
sudo chown -R  sandip:users yay
cd yay
makepkg -sri --needed --noconfirm
cd /dotfiles