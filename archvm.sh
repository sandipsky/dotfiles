#!/usr/bin/env bash

# Disk name
disk="/dev/sda"

# Create GPT partition table
parted $disk mklabel gpt

# Create EFI partition
parted $disk mkpart ESP fat32 1MiB 301MiB
parted $disk set 1 boot on

# Create Swap partition
parted $disk mkpart primary linux-swap 301MiB 4GiB

# Create ext4 partition
parted $disk mkpart primary ext4 4GiB 100%

EFI = "${disk}1"
SWAP =  "${disk}2"
ROOT = "${disk}3"


# make filesystems
echo -e "\nCreating Filesystems...\n"

mkfs.vfat -F32 -n "EFISYSTEM" "${disk}1"

mkswap "${SWAP}"
swapon "${SWAP}"

mkfs.ext4 -L "ROOT" "${ROOT}"

# mount target
mkdir /mnt
mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount -t vfat "${EFI}" /mnt/boot/

echo "--------------------------------------"
echo "-- INSTALLING Arch Linux BASE on Main Drive       --"
echo "--------------------------------------"
pacstrap /mnt base base-devel --noconfirm --needed

# kernel
pacstrap /mnt linux linux-firmware --noconfirm --needed

echo "--------------------------------------"
echo "-- Setup Dependencies               --"
echo "--------------------------------------"

pacstrap /mnt networkmanager network-manager-applet wireless_tools nano intel-ucode bluez bluez-utils blueman git --noconfirm --needed

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "--------------------------------------"
echo "-- Bootloader Systemd Installation  --"
echo "--------------------------------------"

bootctl install --path /mnt/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=${ROOT} rw
EOF

cat <<REALEND > /mnt/next.sh
useradd -m sandip
usermod -aG wheel,storage,power,audio sandip
echo sandip:asd | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

git clone https://github.com/sandipsky/dotfiles/
mv dotfiles /home/sandip/

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "arch" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	arch.localdomain	arch
EOF

echo "-------------------------------------------------"
echo "Display and Audio Drivers"
echo "-------------------------------------------------"

pacman -S xorg-server xorg-server-xwayland xorg-xinit xf86-input-libinput xf86-video-vmware mesa pipewire pipewire-pulse--noconfirm --needed

systemctl enable NetworkManager bluetooth 
systemctl --user enable pipewire-pulse pipewire

echo "-------------------------------------------------"
echo "Minimal Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND


arch-chroot /mnt sh next.sh

