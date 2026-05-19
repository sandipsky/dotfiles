#!/bin/bash
set -e

USERNAME=$(logname)
FULLNAME=$(getent passwd "$USERNAME" | cut -d ':' -f 5 | cut -d ',' -f 1)
FULLNAME=${FULLNAME:-$USERNAME}

sudo pacman -S --noconfirm --needed \
    hyprland \
    wpaperd \
    hyprpicker \
    hyprsunset \
    wl-clipboard \
    cliphist \
    xdg-desktop-portal-hyprland \
    quickshell \
    hyprlock \
    hypridle \
    blueman \
    jq \
    alacritty \
    xdg-user-dirs-gtk \
    obs-studio \
    qbittorrent \
    brightnessctl \
    grim \
    slurp \
    gnome-calculator \
    nautilus \
    evince \
    loupe \
    file-roller \
    gnome-text-editor \
    gvfs-mtp \
    gnome-themes-extra \
    adwaita-icon-theme \
    uwsm

yay -S --noconfirm --needed \
    breezex-cursor-theme \
    nautilus-open-any-terminal 

sudo cp assets/99-power.rules /etc/udev/rules.d/99-power.rules
sudo cp assets/90-usb.rules /etc/udev/rules.d/90-usb.rules
sudo sed -i "s/USERNAME/$USERNAME/g" /etc/udev/rules.d/90-usb.rules
sudo sed -i "s/USERNAME/$USERNAME/g" /etc/udev/rules.d/99-power.rules

dconf load /org/gnome/nautilus/ < assets/nautilus

sudo mkdir -p /usr/share/sounds/
sudo cp assets/sounds/* /usr/share/sounds/

mkdir -p ~/.local/share/applications
cp assets/apps/* ~/.local/share/applications/

files=(
    avahi-discover.desktop
    blueman-adapters.desktop
    blueman-manager.desktop
    bssh.desktop
    bvnc.desktop
    qv4l2.desktop
    qvidcap.desktop
    cmake-gui.desktop
    lstopo.desktop
    java-java21-openjdk.desktop
    jconsole-java21-openjdk.desktop
    jshell-java21-openjdk.desktop
    assistant.desktop
    designer.desktop
    linguist.desktop
    qdbusviewer.desktop
    xgpsspeed.desktop
    xgps.desktop
    vim.desktop
    org.freedesktop.IBus.Setup.desktop
    org.gnome.FileRoller.desktop
    remote-viewer.desktop
)

mkdir -p "$HOME/.local/share/applications"

for file in "${files[@]}"; do
    src="/usr/share/applications/$file"
    dest="$HOME/.local/share/applications/$file"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        echo "NoDisplay=true" >> "$dest"
    fi
done

update-desktop-database ~/.local/share/applications

sudo cp assets/icons/* /usr/share/icons/hicolor/scalable/apps/

sudo mkdir -p /usr/share/fonts
sudo cp assets/fonts/* /usr/share/fonts/
sudo fc-cache -f

rm -rf /home/$USERNAME/.config/*
cp -r config/* /home/$USERNAME/.config/

mkdir -p /home/$USERNAME/.local
cp -r local/* /home/$USERNAME/.local/
chmod +x /home/$USERNAME/.local/bin/*

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --skip-login --nonewline --noissue --noclear %I \$TERM
Type=idle
EOF

tee "/home/$USERNAME/.zprofile" >/dev/null <<'EOF'
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
    if uwsm check may-start; then
        exec uwsm start hyprland.desktop >/dev/null 2>&1
    fi
fi
EOF

LOCK_FILE="/home/$USERNAME/.config/hypr/hyprlock.conf"
sed -i "s/^\s*text = FULLNAME/    text = $FULLNAME/" "$LOCK_FILE"

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal alacritty

xdg-mime default org.gnome.Loupe.desktop image/jpeg
xdg-mime default org.gnome.Loupe.desktop image/png
xdg-mime default org.gnome.Loupe.desktop image/webp

xdg-mime default org.gnome.TextEditor.desktop text/plain
xdg-mime default org.gnome.TextEditor.desktop application/x-shellscript

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

xdg-user-dirs-update

sudo iptables -F || true
sudo iptables -X || true
sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


reboot