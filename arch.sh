#!/usr/bin/env bash

timedatectl set-ntp true

echo "Please enter EFI paritition: (example /dev/sda1 or /dev/nvme0n1p1)"
read EFI

echo "Please enter SWAP paritition: (example /dev/sda2)"
read SWAP

echo "Please enter Root(/) paritition: (example /dev/sda3)"
read ROOT 


# make filesystems
echo -e "\nCreating Filesystems...\n"

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
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

# fstab
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
echo "Enter root password"
passwd
echo "Enter username and password"
read USER
useradd -m $USER
usermod -aG wheel,storage,power,audio $USER
passwd $USER
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

git clone https://github.com/sandipsky/dotfiles/
cd dotfiles

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

pacman -S xorg-server xorg-server-xwayland xorg-xinit xf86-input-synaptics xf86-input-libinput xf86-video-vmware mesa nvidia nvidia-utils pulseaudio --noconfirm --needed

systemctl enable NetworkManager bluetooth

touch /etc/polkit-1/rules.d/49-nopasswd_global.rules
bash -c "cat >> /etc/polkit-1/rules.d/49-nopasswd_global.rules" << EOF
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

chmod +x gnome.sh kde.sh xbspwm.sh aur.sh

sudo -H -u $USER bash -c 'bash /dotfiles/aur.sh'

echo "-------------------------------------------------"
echo "Choose Desktop Environment"
echo "-------------------------------------------------"
echo "1. GNOME"
echo "2. KDE"
echo "3. XFCE + BSPWM"
 
read op
if [[ $op == '1' ]]
then 
    sh gnome.sh
elif [[ $op == '2' ]]
then
    sh kde.sh
else
    sh xbspwm.sh
fi

REALEND


arch-chroot /mnt sh next.sh

