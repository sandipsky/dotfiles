#!/bin/bash

sudo pacman -S plymouth --needed --noconfirm

sudo plymouth-set-default-theme -R bgrt

sudo rm /usr/share/plymouth/themes/spinner/watermark.png

sudo mkinitcpio -P
