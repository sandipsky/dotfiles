sudo systemctl disable snapd.service
sudo systemctl disable snapd.socket
sudo systemctl disable snapd.seeded.service

sudo snap remove gtk-common-themes
sudo snap remove gnome-3-38-2004
sudo snap remove firefox
sudo snap remove bare core20
sudo snap remove snapd

sudo apt autoremove --purge snapd

sudo rm -rf /var/cache/snapd/
rm -rf ~/snap

