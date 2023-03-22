echo "Enter root password"
passwd
echo "Enter username and password"
read USER
useradd -m $USER
passwd $USER
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

hostnamectl --no-ask-password set-hostname $hostname

echo "-------------------------------------------------"
echo "Display and Audio Drivers"
echo "-------------------------------------------------"

echo "Are you on Real Hardware?(y or n)"
read in

if [ $in == 'y' ]
then 
    pacman -S xorg-server xorg-server-xwayland xorg-xinit xf86-input-synaptics xf86-input-libinput mesa nvidia nvidia-utils pulseaudio
else
    pacman -S xorg virtualbox-guest-utils
fi

systemctl enable NetworkManager bluetooth

sudo touch /etc/polkit-1/rules.d/49-nopasswd_global.rules
sudo bash -c "cat >> /etc/polkit-1/rules.d/49-nopasswd_global.rules" << EOF
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

chmod +x gnome.sh kde.sh 

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -sri

echo "-------------------------------------------------"
echo "Choose Desktop Environment"
echo "-------------------------------------------------"
echo "1. GNOME"
echo "2. KDE"
echo "3. Minimal"
 
read op
if [ $op == '1' ]
then 
    ./gnome.sh
eif [ $op == '2' ]
then
    ./kde.sh
else
    exit
fi

