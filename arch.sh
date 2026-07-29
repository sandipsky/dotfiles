#!/usr/bin/env bash
set -e

read -p "EFI partition (e.g. /dev/nvme0n1p1): " EFI
read -p "ROOT partition (e.g. /dev/nvme0n1p2): " ROOT
read -p "Enter NTFS D Drive partition (optional, e.g. /dev/nvme1n1p1, blank to skip): " NTFS_DRIVE
read -p "Username: " USER
read -p "Full Name: " NAME
read -p "Password: " PASSWORD
read -p "Install KDE Plasma desktop? (y/n): " INSTALL_KDE

### -------- FILESYSTEM --------
mkfs.fat -F32 "$EFI"
mkfs.ext4 -F "$ROOT"

mount -o noatime "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$EFI" /mnt/boot

### -------- BASE ARCH --------
pacman -Syy --noconfirm archlinux-keyring

pacstrap /mnt --noconfirm --needed \
base base-devel \
linux linux-headers \
linux-firmware \
networkmanager vim git curl \
intel-ucode \
mesa vulkan-intel intel-media-driver \
dkms \
zram-generator \
power-profiles-daemon \
bluez bluez-utils \
ntfs-3g \
pipewire wireplumber pipewire-alsa pipewire-pulse

genfstab -U /mnt >> /mnt/etc/fstab
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")
NTFS_UUID=""
if [[ -n "$NTFS_DRIVE" ]]; then
    NTFS_UUID=$(blkid -s UUID -o value "$NTFS_DRIVE")
fi
VIRT=$(systemd-detect-virt) || true

### -------- CHROOT SCRIPT --------
cat <<EOF > /mnt/next.sh
#!/usr/bin/env bash
set -e

### --- USER ---
useradd -m "$USER"
usermod -c "$NAME" "$USER"
usermod -aG wheel,video,audio,storage,power "$USER"
echo "$USER:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

### --- LOCALE / TIME ---
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

### --- HOSTNAME ---
echo "archlinux" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 archlinux.localdomain archlinux
HOSTS

### --- VIRTUALBOX DETECTION ---
if [[ "$VIRT" == "oracle" || "$VIRT" == "virtualbox" ]]; then
    echo "VirtualBox detected. Installing guest utilities..."
    pacman -S --noconfirm --needed virtualbox-guest-utils
    usermod -aG vboxsf "$USER"
    systemctl enable vboxservice.service
fi

### --- ZRAM ---
cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAM

### --- AUDIO POWER SAVE (idle codecs suspend; also needed for dGPU D3cold) ---
cat <<'SNDPM' > /etc/modprobe.d/audio-powersave.conf
options snd_hda_intel power_save=1 power_save_controller=Y
SNDPM

### --- MULTILIB ---
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
pacman -Syy --noconfirm

### --- BOOTLOADER ---
# Installed EARLY so the system is always bootable, even if a later
# (network/AUR) step fails under set -e.
bootctl install --esp-path=/boot

cat <<LOADER > /boot/loader/loader.conf
default arch.conf
timeout 0
console-mode keep
editor no
LOADER

cat <<ENTRY > /boot/loader/entries/arch.conf
title   ArchLinux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 i915.fastboot=1 nowatchdog 8250.nr_uarts=0 mitigations=off nvidia-drm.modeset=1
ENTRY

### --- MKINITCPIO (early KMS = flicker-free boot) ---
sed -i 's/^MODULES=.*/MODULES=(i915)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(systemd autodetect modconf block filesystems keyboard)/' /etc/mkinitcpio.conf
sed -i 's/^#\?COMPRESSION=.*/COMPRESSION="zstd"/' /etc/mkinitcpio.conf
sed -i 's/^#\?COMPRESSION_OPTIONS=.*/COMPRESSION_OPTIONS=(-3)/' /etc/mkinitcpio.conf

### --- NVIDIA ---
pacman -S --noconfirm --needed \
    nvidia-open-dkms \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-settings \
    nvidia-prime \
    libva-nvidia-driver \
    opencl-nvidia

### --- NVIDIA RUNTIME POWER MANAGEMENT ---
cat <<'NVPM' > /etc/modprobe.d/nvidia-pm.conf
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia NVreg_EnableS0ixPowerManagement=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
NVPM

systemctl enable nvidia-suspend.service nvidia-resume.service || true

### --- NVIDIA RUNTIME D3 (kernel-side runtime PM so the dGPU powers off) ---
# add|bind: driver binds inside the initramfs (early KMS), where this rule
# isn't present -- matching "add" applies it on the udev coldplug replay.
cat <<'NVUDEV' > /etc/udev/rules.d/80-nvidia-pm.rules
# Enable runtime PM for the NVIDIA GPU and its HDMI audio function
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"

# Revert to always-on when the driver unbinds
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="on"
NVUDEV

### --- MKINITCPIO / NVIDIA (early KMS for the dGPU too) ---
sed -i 's/^MODULES=.*/MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

mkdir -p /etc/pacman.d/hooks
cat <<'NVHOOK' > /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open-dkms
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
NVHOOK

# Rebuild initramfs with the early-KMS modules
mkinitcpio -P

### --- AUR (yay) ---
cd /tmp
sudo -u "$USER" git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u "$USER" makepkg -sri --needed --noconfirm
cd /
rm -rf /tmp/yay


### --- NTFS ROOT PASSWORD FIX ---
cat <<'POLKIT' > /etc/polkit-1/rules.d/49-nopasswd_global.rules
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT

chmod 644 /etc/polkit-1/rules.d/49-nopasswd_global.rules

if [[ -n "$NTFS_DRIVE" ]]; then
    mkdir -p /mnt/HOME
    echo "UUID=$NTFS_UUID /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0" >> /etc/fstab
    mount -a
else
    echo "No separate NTFS drive specified, skipping..."
fi

### --- BATTERY CHARGE THRESHOLD ---
cat <<'BATTERY' > /etc/systemd/system/battery-charge-threshold.service
[Unit]
Description=Set battery charge threshold
After=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
StartLimitBurst=0

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'echo 80 | tee /sys/class/power_supply/BAT*/charge_control_end_threshold > /dev/null'

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
BATTERY

### --- ZSH / STARSHIP ---
pacman -S --noconfirm --needed \
zsh \
zsh-syntax-highlighting \
zsh-autosuggestions \
starship

# Set zsh as default shell for user
chsh -s /bin/zsh "$USER"

cat <<'ZSHRC' > /home/$USER/.zshrc
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

setopt inc_append_history

PROMPT_EOL_MARK=''

eval "\$(starship init zsh)"

export PATH="\$PATH:\$HOME/.local/bin"
ZSHRC

chown $USER:$USER /home/$USER/.zshrc

### --- WINE / GAMING STACK ---
pacman -S --noconfirm --needed \
    wine-staging wine-mono wine-gecko \
    giflib lib32-giflib \
    libpng lib32-libpng \
    libldap lib32-libldap \
    gnutls lib32-gnutls \
    mpg123 lib32-mpg123 \
    openal lib32-openal \
    v4l-utils lib32-v4l-utils \
    libpulse lib32-libpulse \
    libgpg-error lib32-libgpg-error \
    libgcrypt lib32-libgcrypt \
    alsa-plugins lib32-alsa-plugins \
    alsa-lib lib32-alsa-lib \
    libjpeg-turbo lib32-libjpeg-turbo \
    sqlite lib32-sqlite \
    libxcomposite lib32-libxcomposite \
    libxinerama lib32-libxinerama \
    ncurses lib32-ncurses \
    ocl-icd lib32-ocl-icd \
    libxslt lib32-libxslt \
    libva lib32-libva \
    gtk3 lib32-gtk3 \
    gst-plugins-base-libs \
    gst-libav \
    vulkan-intel lib32-vulkan-intel \
    lib32-mesa \
    gst-plugins-good \
    python-protobuf \
    lutris

#FONTS
pacman -S --noconfirm --needed \
    noto-fonts \
    noto-fonts-emoji \
    noto-fonts-extra \
    ttf-liberation \
    noto-fonts-cjk \
    ttf-dejavu \
    otf-font-awesome \
    ttf-fira-sans \
    ttf-jetbrains-mono

#PROGRAMS
pacman -S --noconfirm --needed \
    vlc vlc-plugins-all \
    obs-studio \
    qbittorrent \
    gvfs-mtp \
    ffmpegthumbnailer \
    wget

### --- DEVELOPMENT STACK ---
pacman -S --noconfirm --needed \
    nodejs-lts-krypton \
    npm \
    jdk25-openjdk 

sudo -u "$USER" npm install -g @angular/cli --prefix=/home/$USER/.local

### --- GIT GLOBAL CONFIG ---
sudo -u "$USER" git config --global user.name "sandipsky"
sudo -u "$USER" git config --global user.email "sandipshakya75@gmail.com"
sudo -u "$USER" git config --global core.pager cat

### --- AUR APPS ---
sudo -u "$USER" yay -S google-chrome visual-studio-code-bin neofetch --noconfirm --needed

### --- DESKTOP (KDE) ---
if [[ "$INSTALL_KDE" == "y" || "$INSTALL_KDE" == "Y" ]]; then
    pacman -S --noconfirm --needed \
        plasma-meta \
        konsole \
        ark \
        dolphin \
        sddm

    systemctl enable sddm.service
fi

### --- SERVICES ---
systemctl enable NetworkManager bluetooth power-profiles-daemon fstrim.timer
systemctl enable battery-charge-threshold.service
systemctl --global enable pipewire pipewire-pulse wireplumber

systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service

echo "INSTALLATION COMPLETE"
EOF

chmod +x /mnt/next.sh
arch-chroot /mnt /next.sh
rm /mnt/next.sh

echo "DONE. You can reboot now."
