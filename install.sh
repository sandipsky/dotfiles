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

sudo -u "$USERNAME" -H dbus-run-session -- dconf load /org/gnome/nautilus/ < assets/nautilus

sudo mkdir -p /usr/share/sounds/
sudo cp assets/sounds/* /usr/share/sounds/

sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.local/share/applications"
sudo -u "$USERNAME" cp assets/apps/* "/home/$USERNAME/.local/share/applications/"

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

APPS_DIR="/home/$USERNAME/.local/share/applications"
sudo -u "$USERNAME" mkdir -p "$APPS_DIR"

for file in "${files[@]}"; do
    src="/usr/share/applications/$file"
    dest="$APPS_DIR/$file"

    if [[ -f "$src" ]]; then
        sudo -u "$USERNAME" cp "$src" "$dest"
        sudo -u "$USERNAME" bash -c "echo 'NoDisplay=true' >> '$dest'"
    fi
done

sudo -u "$USERNAME" update-desktop-database "$APPS_DIR"

sudo cp assets/icons/* /usr/share/icons/hicolor/scalable/apps/

sudo mkdir -p /usr/share/fonts
sudo cp assets/fonts/* /usr/share/fonts/
sudo fc-cache -f

sudo -u "$USERNAME" cp -r config/* "/home/$USERNAME/.config/"

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

sudo -u "$USERNAME" -H dbus-run-session -- bash <<'EOF'
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal alacritty
EOF

sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/jpeg
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/png
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/webp

sudo -u "$USERNAME" -H xdg-mime default org.gnome.TextEditor.desktop text/plain
sudo -u "$USERNAME" -H xdg-mime default org.gnome.TextEditor.desktop application/x-shellscript

sudo -u "$USERNAME" -H bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

sudo -u "$USERNAME" -H xdg-user-dirs-update

sudo iptables -F || true
sudo iptables -X || true
sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


reboot