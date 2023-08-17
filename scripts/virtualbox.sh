sudo pacman -S virtualbox-guest-utils

sudo systemctl enable --now vboxservice

sudo usermod -a -G vboxsf sandip
sudo chown -R sandip:users /media