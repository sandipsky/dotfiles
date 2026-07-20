#!/bin/bash
set -e

USERNAME=$(logname)

# Some routers hand out dead DNS servers via DHCP (the GLX router's first one,
# 110.44.112.200, never answers and glibc stalls 5 s per lookup on it). Prefer
# known-good resolvers globally — Domains=~. outranks any network's DHCP DNS —
# and cache via systemd-resolved, which also auto-skips unresponsive servers.
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/10-global-dns.conf > /dev/null <<'EOF'
[Resolve]
DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
Domains=~.
EOF
sudo systemctl enable --now systemd-resolved.service
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart NetworkManager
for _ in $(seq 1 30); do
    if nmcli -t -f STATE general 2>/dev/null | grep -q '^connected'; then
        break
    fi
    sleep 1
done

sudo pacman -S --noconfirm --needed \
    hyprland \
    hyprpicker \
    wl-clipboard \
    cliphist \
    wtype \
    xdg-desktop-portal-hyprland \
    wlsunset \
    power-profiles-daemon \
    blueman \
    jq \
    alacritty \
    xdg-user-dirs-gtk \
    obs-studio \
    qbittorrent \
    brightnessctl \
    imagemagick \
    ffmpeg \
    qt6-multimedia \
    python \
    wlr-randr \
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
    breezex-cursor-theme

sudo -u "$USERNAME" -H bash -c "curl -fsSL https://claude.ai/install.sh | bash"

# noctalia-qs is built only from the vendored recipe in applications/ — upstream
# discontinued the fork (v5 dropped Quickshell), so the AUR package is
# unmaintained and must not be trusted for unattended --noconfirm builds.
if ! pacman -Qq noctalia-qs >/dev/null 2>&1; then
    BUILD_DIR=$(sudo -u "$USERNAME" mktemp -d)
    sudo -u "$USERNAME" cp -r applications/noctalia-qs/. "$BUILD_DIR/"
    (cd "$BUILD_DIR" && sudo -u "$USERNAME" makepkg -s --noconfirm)
    pacman -U --noconfirm "$BUILD_DIR"/noctalia-qs-0*.pkg.tar.zst
    rm -rf "$BUILD_DIR"
fi

# Nautilus is replaced by the local fork vendored in applications/nautilus-fork/
# (upstream source + local patches, see docs/nautilus-patches.md), built
# fully offline from the repo tree. The repo nautilus installed above only
# serves to pull in runtime deps before the fork overwrites it. IgnorePkg
# then keeps pacman -Syu from replacing the fork with a newer repo package —
# upgrades happen by bumping the vendored tree (see rebuild-nautilus.sh).
BUILD_DIR=$(sudo -u "$USERNAME" mktemp -d)
sudo -u "$USERNAME" cp -r applications/nautilus-fork/. "$BUILD_DIR/"
(cd "$BUILD_DIR" && sudo -u "$USERNAME" makepkg -s --noconfirm)
pacman -U --noconfirm "$BUILD_DIR"/nautilus-*.pkg.tar.zst "$BUILD_DIR"/libnautilus-extension-*.pkg.tar.zst
rm -rf "$BUILD_DIR"
if ! grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*nautilus' /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a IgnorePkg = nautilus libnautilus-extension' /etc/pacman.conf
fi

sudo cp assets/99-power.rules /etc/udev/rules.d/99-power.rules
sudo sed -i "s/USERNAME/$USERNAME/g" /etc/udev/rules.d/99-power.rules

if [[ -f /etc/bluetooth/main.conf ]]; then
    if grep -q '^#*AutoEnable=' /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#*AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
    else
        printf '\n[Policy]\nAutoEnable=false\n' | sudo tee -a /etc/bluetooth/main.conf >/dev/null
    fi
fi

sudo -u "$USERNAME" -H dbus-run-session -- dconf load /org/gnome/nautilus/ < assets/nautilus

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
    java-java25-openjdk.desktop
    jconsole-java25-openjdk.desktop
    jshell-java25-openjdk.desktop
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
    assistant.desktop
    qdbusviewer.desktop
    linguist.desktop
    designer.desktop
    uuctl.desktop
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

# extract-audio: pulls audio out of videos as MP3 (Resolve on Linux can't
# decode AAC, so H.264 clips import silent without it). ffmpeg is in the
# pacman list above. /usr/local/bin so it works from any shell/directory.
sudo install -Dm755 assets/bin/extract-audio /usr/local/bin/extract-audio

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

sudo -u "$USERNAME" sed -i "s|USERNAME|$USERNAME|g" "/home/$USERNAME/.config/noctalia/settings.json"
sudo -u "$USERNAME" cp assets/profile.png "/home/$USERNAME/.face"

sudo -u "$USERNAME" -H dbus-run-session -- bash <<'EOF'
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
EOF

sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/jpeg
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/png
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Loupe.desktop image/webp

sudo -u "$USERNAME" -H xdg-mime default org.gnome.TextEditor.desktop text/plain
sudo -u "$USERNAME" -H xdg-mime default org.gnome.TextEditor.desktop application/x-shellscript

sudo -u "$USERNAME" -H xdg-user-dirs-update

sudo -u "$USERNAME" -H bash -c "cd '$PWD/applications/music' && echo Y | ./install.sh"

sudo -u "$USERNAME" rm -f /home/$USERNAME/.gnupg/public-keys.d/pubring.db.lock
sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


reboot