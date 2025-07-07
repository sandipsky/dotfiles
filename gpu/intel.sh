
sudo pacman -Rnsc --noconfirm nvidia nvidia-utils nvidia-settings opencl-nvidia nvidia-prime

sudo pacman -Sc --noconfirm

sudo rm -rf /etc/X11/xorg.conf.d/90-nvidia.conf /etc/modprobe.d/nvidia.conf

sudo rm /etc/modprobe.d/blacklist-nvidia.conf
sudo cp blacklist-nvidia.conf /etc/modprobe.d/blacklist-nvidia.conf

sudo rm /lib/udev/rules.d/50-remove-nvidia.rules
sudo cp 50-remove-nvidia.rules /lib/udev/rules.d/50-remove-nvidia.rules
