#!/usr/bin/env bash

echo "Please enter EFI paritition: (example /dev/sda1 or /dev/nvme0n1p1)"
read EFI

echo "Please enter Root(/) paritition: (example /dev/sda3)"
read ROOT 

echo "Please enter your Username"
read USER 

echo "Please enter your Full Name"
read NAME 

echo "Please enter your Password"
read PASSWORD 

echo "Please choose Your Desktop Environment"
echo "1. GNOME"
echo "2. KDE"
echo "3. XFCE"
echo "4. NoDesktop"
read DESKTOP

# make filesystems
echo -e "\nCreating Filesystems...\n"

echo "Do you want to FORMAT EFI PARTITION? Yy/Nn (Choose yes for newly created Partition)"
read ISFORMAT

if [[ $ISFORMAT == 'y' || $ISFORMAT == 'Y' ]]
then 
    mkfs.vfat -F32 "${EFI}"
fi 

mkfs.ext4 "${ROOT}"

# mount target
mount "${ROOT}" /mnt
mkdir /mnt/boot/efi
mount "${EFI}" /mnt/boot/efi

echo "--------------------------------------"
echo "-- INSTALLING Base Arch Linux --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware linux-headers networkmanager network-manager-applet wireless_tools nano intel-ucode bluez bluez-utils git--noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Arch Linux"
grub-mkconfig -o /boot/grub/grub.cfg


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

pacman -S pipewire pipewire-alsa pipewire-pulse --noconfirm --needed

systemctl enable NetworkManager bluetooth
systemctl --user enable pipewire pipewire-pulse

#DESKTOP ENVIRONMENT
if [[ $DESKTOP == '1' ]]
then 
    pacman -S gnome gdm --noconfirm --needed
    systemctl enable gdm
elif [[ $DESKTOP == '2' ]]
then
    pacman -S plasma sddm kde-applications --noconfirm --needed
    systemctl enable sddm
elif [[ $DESKTOP == '3' ]]
then
    pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter --noconfirm --needed
    systemctl enable lightdm
else
    echo "You have choosen to Install Desktop Yourself"
fi

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND


arch-chroot /mnt sh next.sh

