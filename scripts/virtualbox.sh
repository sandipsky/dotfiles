sudo pacman -S virtualbox-guest-utils

sudo systemctl enable --now vboxservice

sudo usermod -a -G vboxsf sandipsky
sudo chown -R sandipsky:users /media