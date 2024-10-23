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

# make filesystems
echo -e "\nCreating Filesystems...\n"

existing_fs=$(blkid -s TYPE -o value "$EFI")
if [[ "$existing_fs" != "vfat" ]]; then
    mkfs.vfat -F32 "$EFI"
fi

mkfs.ext4 "${ROOT}"

# mount target
mount "${ROOT}" /mnt
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")
mount --mkdir "$EFI" /mnt/boot/efi


echo "--------------------------------------"
echo "-- INSTALLING Base Arch Linux --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware linux-headers networkmanager wireless_tools nano intel-ucode bluez bluez-utils git --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
useradd -m $USER
usermod -c "${NAME}" $USER
usermod -aG wheel,storage,power,audio,video $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "asus-f15" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	asus-f15.localdomain	asus-f15
127.0.0.1   front1.rms.local
192.168.0.124 front1.rms
127.0.0.1   front1.ims.local
192.168.0.153 front1.ims
127.0.0.1   front1.dpms.local
192.168.0.164 front1.dpms
EOF

echo "-------------------------------------------------"
echo "Audio Drivers"
echo "-------------------------------------------------"

pacman -S mesa-utils nvidia nvidia-utils nvidia-settings opencl-nvidia nvidia-prime pipewire pipewire-alsa pipewire-pulse --noconfirm --needed

systemctl enable NetworkManager bluetooth
systemctl --user enable pipewire pipewire-pulse

echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"

pacman -S grub efibootmgr --noconfirm --needed
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu --modules="normal test efi_gop efi_uga search echo linux all_video gfxmenu gfxterm_background gfxterm_menu gfxterm loadenv configfile tpm" --disable-shim-lock
grub-mkconfig -o /boot/grub/grub.cfg

cd /home/sandip
git clone https://github.com/sandipsky/dotfiles

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND

arch-chroot /mnt sh next.sh

