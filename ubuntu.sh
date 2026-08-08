#!/usr/bin/env bash
# Post-install setup for a FRESH Ubuntu install (GNOME desktop).
# Ubuntu counterpart of arch.sh — run it from the repo root with:
#   sudo ./ubuntu.sh
#
# Notes:
# - The music app builds from the vendored tree in applications/. Nautilus is
#   the stock Ubuntu package (the vendored fork is Arch-only).
# - Chrome / VS Code / Docker come from the vendors' own apt repos (the deb
#   equivalent of a PPA). Postman has no deb, so it installs from the official
#   tarball into /opt. Spotify comes from Spotify's apt repo with
#   spotify-adblock built from source, same as fedora.sh.
# - The dev stack and the gaming stack are each prompted up front; VirtualBox
#   guests get the guest additions automatically.
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Run this script with sudo: sudo ./ubuntu.sh"
    exit 1
fi

USERNAME=$(logname)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

. /etc/os-release
CODENAME="${VERSION_CODENAME}"

# "oracle" = VirtualBox; systemd-detect-virt exits non-zero on bare metal.
VIRT=$(systemd-detect-virt 2>/dev/null) || VIRT=none

### -------- PROMPTS (everything interactive happens up front) --------
echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
echo
read -rp "NTFS partition to mount at /mnt/HOME (e.g. /dev/nvme1n1p1, blank to skip): " NTFS_DRIVE
read -rp "Install the development stack (node, JDK, Angular CLI, Docker, Postman)? [Y/n]: " INSTALL_DEV
read -rp "Install the gaming stack (wine, winetricks, lutris)? [Y/n]: " INSTALL_GAMING

### -------- BASE UPDATE --------
apt-get update
apt-get full-upgrade -y

### -------- REMOVE SNAP --------
# Remove every snap (a few passes so dependency order — apps, then bases,
# then core/snapd — resolves itself), then purge snapd and all its caches,
# and pin it so nothing pulls it back in later.
if command -v snap >/dev/null 2>&1; then
    for _ in 1 2 3 4 5; do
        SNAPS=$(snap list 2>/dev/null | awk 'NR>1 {print $1}') || SNAPS=""
        [[ -z "$SNAPS" ]] && break
        for s in $SNAPS; do
            snap remove --purge "$s" 2>/dev/null || true
        done
    done
    systemctl disable --now snapd.socket snapd.service snapd.seeded.service 2>/dev/null || true
fi
apt-get purge -y snapd gnome-software-plugin-snap 2>/dev/null || apt-get purge -y snapd || true
apt-get autoremove -y --purge
rm -rf /var/cache/snapd /var/snap /snap /root/snap "/home/$USERNAME/snap"

cat > /etc/apt/preferences.d/nosnap.pref <<'EOF'
# Keep snapd from ever being reinstalled (e.g. as a dependency).
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

### -------- THIRD-PARTY APT REPOS (Chrome, VS Code, Docker) --------
# git and jq live here, not in the dev stack — Spotify-adblock and the GNOME
# extension installer below need them even when the dev stack is skipped.
apt-get install -y curl wget gpg apt-transport-https ca-certificates git jq
install -d -m 0755 /etc/apt/keyrings

# Google Chrome
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list

# Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y google-chrome-stable code

### -------- WINE / GAMING STACK (optional) --------
if [[ "$INSTALL_GAMING" =~ ^[Nn] ]]; then
    echo "Skipping the gaming stack."
else
    dpkg --add-architecture i386

    # WineHQ staging (falls back to Ubuntu's own wine if WineHQ doesn't carry
    # this release's codename yet).
    if wget -q -O "/etc/apt/sources.list.d/winehq-$CODENAME.sources" \
            "https://dl.winehq.org/wine-builds/ubuntu/dists/$CODENAME/winehq-$CODENAME.sources"; then
        wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
        apt-get update
        apt-get install -y --install-recommends winehq-staging
    else
        rm -f "/etc/apt/sources.list.d/winehq-$CODENAME.sources"
        echo "WineHQ has no repo for '$CODENAME' yet — installing Ubuntu's wine instead."
        apt-get update
        apt-get install -y --install-recommends wine
    fi

    apt-get install -y winetricks lutris
fi

### -------- VIRTUALBOX GUEST ADDITIONS --------
if [[ "$VIRT" == "oracle" || "$VIRT" == "virtualbox" ]]; then
    echo "VirtualBox detected — installing guest additions."
    apt-get install -y virtualbox-guest-utils virtualbox-guest-x11 \
        || apt-get install -y virtualbox-guest-utils \
        || echo "Guest additions install failed — clipboard/resolution integration won't work."
    # Shared folders mount as root:vboxsf.
    getent group vboxsf >/dev/null && usermod -aG vboxsf "$USERNAME" || true
    systemctl enable virtualbox-guest-utils.service 2>/dev/null || true
fi

### -------- PROGRAMS --------
apt-get install -y \
    vlc \
    obs-studio \
    qbittorrent

### -------- GNOME SOFTWARE (deb packages only) --------
# --no-install-recommends keeps the snap plugin out (Ubuntu recommends it);
# the flatpak plugin is never installed, and both are purged in case something
# pulled them in. Deb support comes from packagekit, which is a hard dep.
apt-get install -y --no-install-recommends gnome-software packagekit
apt-get purge -y gnome-software-plugin-flatpak gnome-software-plugin-snap 2>/dev/null || true

### -------- GNOME CONSOLE (replace Ptyxis / GNOME Terminal) --------
# GNOME Console (kgx) in; it gets GNOME Terminal's icon in the app-icons
# step below. Separate purges — one absent package must not spare the other.
apt-get install -y gnome-console
apt-get purge -y ptyxis 2>/dev/null || true
apt-get purge -y gnome-terminal 2>/dev/null || true

### -------- DEVELOPMENT STACK (optional) --------
if [[ "$INSTALL_DEV" =~ ^[Nn] ]]; then
    echo "Skipping the development stack."
else
    apt-get install -y build-essential pkg-config

    # Node.js LTS via NodeSource (Ubuntu's own nodejs is too old)
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs

    # JDK — newest available, mirroring arch.sh's jdk25
    apt-get install -y openjdk-25-jdk 2>/dev/null \
        || apt-get install -y openjdk-21-jdk 2>/dev/null \
        || apt-get install -y default-jdk

    sudo -u "$USERNAME" -H npm install -g @angular/cli --prefix="/home/$USERNAME/.local"

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker "$USERNAME"

    # Postman has no deb — official tarball into /opt.
    POSTMAN_TAR=$(mktemp)
    curl -fsSL https://dl.pstmn.io/download/latest/linux_64 -o "$POSTMAN_TAR"
    rm -rf /opt/Postman
    tar -xzf "$POSTMAN_TAR" -C /opt
    rm -f "$POSTMAN_TAR"
    ln -sf /opt/Postman/Postman /usr/local/bin/postman
    cat > /usr/share/applications/postman.desktop <<'EOF'
[Desktop Entry]
Name=Postman
Exec=/opt/Postman/Postman %U
Icon=/opt/Postman/app/resources/app/assets/icon.png
Type=Application
Categories=Development;
Terminal=false
EOF
fi

### -------- GIT GLOBAL CONFIG (only when not already set) --------
sudo -u "$USERNAME" -H git config --global user.name >/dev/null 2>&1 \
    || sudo -u "$USERNAME" -H git config --global user.name "sandipsky"
sudo -u "$USERNAME" -H git config --global user.email >/dev/null 2>&1 \
    || sudo -u "$USERNAME" -H git config --global user.email "sandipshakya75@gmail.com"
sudo -u "$USERNAME" -H git config --global core.pager >/dev/null 2>&1 \
    || sudo -u "$USERNAME" -H git config --global core.pager cat

### -------- BATTERY CHARGE THRESHOLD (80%) --------
cat > /etc/systemd/system/battery-charge-threshold.service <<'EOF'
[Unit]
Description=Set battery charge threshold
After=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
StartLimitBurst=0

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'echo 80 | tee /sys/class/power_supply/BAT*/charge_control_end_threshold > /dev/null'

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF
systemctl daemon-reload
systemctl enable battery-charge-threshold.service
systemctl start battery-charge-threshold.service || true

### -------- SILENT + FAST BOOT --------
# "splash" stays in the cmdline so the Plymouth spinner still shows.
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 i915.fastboot=1 nowatchdog mitigations=off"/' /etc/default/grub
# Without this, GRUB shows a 30 s menu after any unclean shutdown.
if grep -q '^GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub; then
    sed -i 's/^GRUB_RECORDFAIL_TIMEOUT=.*/GRUB_RECORDFAIL_TIMEOUT=0/' /etc/default/grub
else
    echo 'GRUB_RECORDFAIL_TIMEOUT=0' >> /etc/default/grub
fi
# Windows boots via the firmware boot menu (Esc on ASUS) — keep os-prober off
# so it never reappears in (and slows down) update-grub.
if grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub
else
    echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
fi
update-grub

# Biggest boot-time win: don't block boot waiting for the network.
systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service 2>/dev/null || true

### -------- NTFS DRIVE --------
if [[ -n "$NTFS_DRIVE" ]]; then
    apt-get install -y ntfs-3g
    NTFS_UUID=$(blkid -s UUID -o value "$NTFS_DRIVE" 2>/dev/null) || NTFS_UUID=""
    if [[ -n "$NTFS_UUID" ]]; then
        mkdir -p /mnt/HOME
        if ! grep -q "UUID=$NTFS_UUID" /etc/fstab; then
            echo "UUID=$NTFS_UUID /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0" >> /etc/fstab
        fi
        systemctl daemon-reload
        mount -a || echo "Mounting $NTFS_DRIVE failed — check /etc/fstab."
    else
        echo "No UUID found on $NTFS_DRIVE — skipping the NTFS mount."
    fi
else
    echo "No NTFS drive specified, skipping..."
fi

### -------- MUSIC APP (applications/music) --------
# Its own install.sh is Arch-only (pacman) — install the deb equivalents of
# its dep list and drive meson directly, into the user's ~/.local.
apt-get install -y \
    meson ninja-build gcc \
    libgtk-4-dev libadwaita-1-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav \
    desktop-file-utils hicolor-icon-theme

MUSIC_BUILD=$(sudo -u "$USERNAME" mktemp -d)
sudo -u "$USERNAME" -H meson setup "$MUSIC_BUILD" "$REPO_DIR/applications/music" --prefix="/home/$USERNAME/.local"
sudo -u "$USERNAME" -H meson compile -C "$MUSIC_BUILD"
sudo -u "$USERNAME" -H meson install -C "$MUSIC_BUILD"
rm -rf "$MUSIC_BUILD"
sudo -u "$USERNAME" -H update-desktop-database "/home/$USERNAME/.local/share/applications" 2>/dev/null || true
sudo -u "$USERNAME" -H gtk-update-icon-cache -q -t -f "/home/$USERNAME/.local/share/icons/hicolor" 2>/dev/null || true

### -------- SPOTIFY (+ adblock) --------
# Spotify's own apt repo + spotify-adblock built from source and preloaded via
# a .desktop override in /usr/local — same arrangement as fedora.sh.
# Best-effort: any failure just skips Spotify.
install_spotify() {
    curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg \
        | gpg --dearmor --yes -o /etc/apt/keyrings/spotify.gpg || return 1
    echo "deb [signed-by=/etc/apt/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" \
        > /etc/apt/sources.list.d/spotify.list
    # Drop the repo again on failure so it can't poison every later apt update.
    if ! apt-get update; then
        rm -f /etc/apt/sources.list.d/spotify.list
        apt-get update || true
        return 1
    fi
    apt-get install -y spotify-client || return 1

    apt-get install -y cargo make || return 1
    local build so
    build=$(mktemp -d) || return 1
    git clone --depth 1 https://github.com/abba23/spotify-adblock.git "$build/spotify-adblock" || return 1
    make -C "$build/spotify-adblock" || return 1
    so=$(find "$build/spotify-adblock/target/release" -maxdepth 1 -name 'lib*.so' | head -1)
    [[ -n "$so" ]] || return 1
    install -Dm755 "$so" /usr/lib/spotify-adblock.so || return 1
    install -Dm644 "$build/spotify-adblock/config.toml" /etc/spotify-adblock/config.toml || return 1
    rm -rf "$build"

    if [[ -f /usr/share/applications/spotify.desktop ]]; then
        mkdir -p /usr/local/share/applications
        cp /usr/share/applications/spotify.desktop /usr/local/share/applications/spotify.desktop
        sed -i 's|^Exec=|Exec=env LD_PRELOAD=/usr/lib/spotify-adblock.so |' \
            /usr/local/share/applications/spotify.desktop
    fi
}
echo "Installing Spotify with ad blocking..."
install_spotify || echo "Spotify/spotify-adblock install failed — skipping. (Did Spotify rotate its apt signing key? Check https://www.spotify.com/download/linux/)"

### -------- APP ICONS (assets/icons) --------
ICON_DIR=/usr/share/icons/hicolor/scalable/apps
mkdir -p "$ICON_DIR"
cp "$REPO_DIR"/assets/icons/* "$ICON_DIR/"
# Papers is Evince's GNOME successor; reuse the same icon under its name.
cp "$REPO_DIR/assets/icons/org.gnome.Evince.svg" "$ICON_DIR/org.gnome.Papers.svg"
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

# Ubuntu's Yaru icon theme ships its own icons for these apps and outranks
# hicolor, so point the .desktop files at the SVGs directly, via overrides in
# /usr/local/share/applications (which outranks /usr/share).
mkdir -p /usr/local/share/applications
declare -A ICON_OVERRIDES=(
    [org.gnome.Console.desktop]=org.gnome.Terminal.svg
    [org.gnome.Evince.desktop]=org.gnome.Evince.svg
    [org.gnome.Papers.desktop]=org.gnome.Papers.svg
    [org.gnome.Software.desktop]=org.gnome.Software.svg
    [org.gnome.Nautilus.desktop]=org.gnome.Nautilus.svg
)
for desktop in "${!ICON_OVERRIDES[@]}"; do
    src="/usr/share/applications/$desktop"
    [[ -f "$src" ]] || continue
    cp "$src" "/usr/local/share/applications/$desktop"
    sed -i "s|^Icon=.*|Icon=$ICON_DIR/${ICON_OVERRIDES[$desktop]}|" \
        "/usr/local/share/applications/$desktop"
done

update-desktop-database /usr/local/share/applications 2>/dev/null || true

### -------- FIRA SANS FONT (assets/fira) --------
# Same interface font as arch.sh sets; Debian convention puts TTFs under
# /usr/share/fonts/truetype.
mkdir -p /usr/share/fonts/truetype/fira
cp "$REPO_DIR"/assets/fira/*.ttf /usr/share/fonts/truetype/fira/
fc-cache -f

sudo -u "$USERNAME" -H dbus-run-session -- bash <<'EOF'
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface document-font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Fira Sans Bold 12'
EOF

### -------- GNOME SHELL EXTENSION --------
# "Disable Workspace Switcher Overlay" from extensions.gnome.org, fetched for
# the running Shell version — same as fedora.sh. No Dash to Dock here: Ubuntu
# already ships its own dock.
install_ego_extension() {
    local pk=$1 shell_ver meta uuid url tmp
    shell_ver=$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [[ -n "$shell_ver" ]] || return 1
    meta=$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=$pk&shell_version=$shell_ver") || return 1
    uuid=$(jq -r '.uuid // empty' <<<"$meta")
    url=$(jq -r '.download_url // empty' <<<"$meta")
    [[ -n "$uuid" && -n "$url" ]] || return 1
    tmp=$(mktemp -d) || return 1
    curl -fsSL "https://extensions.gnome.org$url" -o "$tmp/ext.zip" || return 1
    # The zip must be readable by the user — mktemp -d as root is 0700.
    chmod 755 "$tmp" && chmod 644 "$tmp/ext.zip"
    sudo -u "$USERNAME" -H gnome-extensions install --force "$tmp/ext.zip" >&2 || return 1
    rm -rf "$tmp"
    echo "$uuid"
}
if EXT_UUID=$(install_ego_extension 6358); then
    sudo -u "$USERNAME" -H dbus-run-session -- gnome-extensions enable "$EXT_UUID" \
        || echo "Installed but could not enable $EXT_UUID — enable it in the Extensions app."
else
    echo "Could not install 'Disable Workspace Switcher Overlay' (e.g.o #6358) — no build for this GNOME Shell?"
fi

echo
echo "INSTALLATION COMPLETE"
echo " - Reboot to apply the silent/fast boot changes."
echo " - Log out and back in for the docker group and Fira Sans font to take effect."
