#!/usr/bin/env bash

echo "Please enter EFI paritition: (example /dev/sda1 or /dev/nvme0n1p1)"
read EFI

echo "Do you want to FORMAT EFI PARTITION? Yy/Nn (Choose yes for newly created Partition)"
read ISFORMAT

echo "Please enter Root(/) paritition: (example /dev/sda3)"
read ROOT 

echo "Please choose Bootloader"
echo "1. Grub(Default)"
echo "2. Systemd-boot"
read BOOT 

echo "Please enter your Username"
read USER 

echo "Please enter your Full Name"
read NAME 

echo "Please enter your Password"
read PASSWORD 

# make filesystems
echo -e "\nCreating Filesystems...\n"

if [[ $ISFORMAT == 'y' || $ISFORMAT == 'Y' ]]
then 
    mkfs.vfat -F32 "${EFI}"
fi 

mkfs.ext4 "${ROOT}"

# mount target
mount "${ROOT}" /mnt

if [[ $BOOT == '1' ]]
then 
    mount --mkdir "${EFI}" /mnt/boot
else
    mount --mkdir "${EFI}" /mnt/boot/efi
fi

echo "--------------------------------------"
echo "-- INSTALLING Base Arch Linux --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware linux-headers networkmanager network-manager-applet wireless_tools nano intel-ucode bluez bluez-utils git --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
useradd -m $USER
usermod -c "${NAME}" $USER
usermod -aG wheel,storage,power,audio $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "archlinux" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	archlinux.localdomain	archlinux
EOF

echo "-------------------------------------------------"
echo "Audio Drivers"
echo "-------------------------------------------------"

pacman -S mesa-utils pipewire pipewire-alsa pipewire-pulse --noconfirm --needed

systemctl enable NetworkManager bluetooth
systemctl --user enable pipewire pipewire-pulse

echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"

if [[ $BOOT == '2' ]]
then 
    bootctl install --path /mnt/boot
    echo "default arch.conf" >> /mnt/boot/loader/loader.conf
    cat <<EOF > /mnt/boot/loader/entries/arch.conf
    title Arch Linux
    linux /vmlinuz-linux
    initrd /initramfs-linux.img
    options root=${ROOT} rw
    EOF
else
    pacman -S grub efibootmgr --noconfirm --needed
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Arch Linux"
    grub-mkconfig -o /boot/grub/grub.cfg
fi

cd /home/sandip
git clone https://github.com/sandipsky/dotfiles

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND


arch-chroot /mnt sh next.sh

