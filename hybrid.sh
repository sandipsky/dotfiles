sudo pacman -S nvidia-prime -y

cd ..
cd gpu

sudo rm -rf /etc/modprobe.d/blacklist-nvidia.conf /lib/udev/rules.d/50-remove-nvidia.rules

sudo rm -rf /etc/X11/xorg.conf.d/90-nvidia.conf /etc/modprobe.d/nvidia.conf

#use prime-run {appname}