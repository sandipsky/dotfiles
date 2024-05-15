#!/bin/bash

sudo pacman -S plymouth --needed --noconfirm
sudo plymouth-set-default-theme -R bgrt
sudo rm /usr/share/plymouth/themes/spinner/watermark.png
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 systemd.show_status=false rd.udev.log_level=3"/' /etc/default/grub
sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
sudo sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

sudo sed -i "/echo    'Loading Linux linux ...'/d" /boot/grub/grub.cfg
sudo sed -i "/echo    'Loading initial ramdisk ...'/d" /boot/grub/grub.cfg

