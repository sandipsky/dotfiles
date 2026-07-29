#!/usr/bin/env bash
# Post-install setup for a FRESH Ubuntu install (GNOME desktop).
# Ubuntu counterpart of arch.sh — run it from the repo root with:
#   sudo ./ubuntu.sh
#
# Notes:
# - Nautilus fork + music app build from the vendored trees in applications/.
#   The Nautilus fork is upstream 50.2.2, so this expects an Ubuntu release
#   shipping GNOME 50 (26.04+) — `apt build-dep nautilus` pulls the right devs.
# - Chrome / VS Code / Docker come from the vendors' own apt repos (the deb
#   equivalent of a PPA). Postman has no deb, so it installs from the official
#   tarball into /opt.
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

### -------- PROMPTS (everything interactive happens up front) --------
echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
echo
read -rp "NTFS partition to mount at /mnt/HOME (e.g. /dev/nvme1n1p1, blank to skip): " NTFS_DRIVE

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
apt-get install -y curl wget gpg apt-transport-https ca-certificates
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

### -------- WINE / GAMING STACK --------
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

### -------- GNOME TERMINAL (replace Ptyxis) --------
apt-get install -y gnome-terminal
apt-get purge -y ptyxis 2>/dev/null || true

### -------- DEVELOPMENT STACK --------
apt-get install -y build-essential git pkg-config jq

# Node.js LTS via NodeSource (Ubuntu's own nodejs is too old)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# JDK — newest available, mirroring arch.sh's jdk25
apt-get install -y openjdk-25-jdk 2>/dev/null \
    || apt-get install -y openjdk-21-jdk 2>/dev/null \
    || apt-get install -y default-jdk

sudo -u "$USERNAME" -H npm install -g @angular/cli --prefix="/home/$USERNAME/.local"

# Docker CLI + engine (CLI alone can't do anything without a daemon)
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker "$USERNAME"

# Postman — no deb/apt package exists; official tarball into /opt
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

### -------- GIT GLOBAL CONFIG --------
sudo -u "$USERNAME" -H git config --global user.name "sandipsky"
sudo -u "$USERNAME" -H git config --global user.email "sandipshakya75@gmail.com"
sudo -u "$USERNAME" -H git config --global core.pager cat

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
update-grub

# Biggest boot-time win: don't block boot waiting for the network.
systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service 2>/dev/null || true

### -------- NTFS DRIVE --------
if [[ -n "$NTFS_DRIVE" ]]; then
    apt-get install -y ntfs-3g
    NTFS_UUID=$(blkid -s UUID -o value "$NTFS_DRIVE")
    mkdir -p /mnt/HOME
    if ! grep -q "UUID=$NTFS_UUID" /etc/fstab; then
        echo "UUID=$NTFS_UUID /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0" >> /etc/fstab
    fi
    systemctl daemon-reload
    mount -a
else
    echo "No NTFS drive specified, skipping..."
fi

### -------- MUSIC APP (applications/music) --------
# Its install.sh is Arch-only (pacman), so install the deb equivalents of its
# dep list here and drive meson directly, as the script's own fallback
# instructions describe. Installs to the user's ~/.local.
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

### -------- NAUTILUS FORK (applications/nautilus-fork) --------
# No makepkg on Ubuntu, so the vendored tree (upstream 50.2.2 + local patches,
# see docs/nautilus-patches.md) is built with meson into /usr/local, which
# shadows the stock nautilus package (PATH, XDG_DATA_DIRS and D-Bus activation
# all prefer /usr/local). The stock package stays installed for its runtime
# deps (gvfs, tracker, etc.) but its binary is never the one that runs.
# Day-to-day fork changes: run ./rebuild-nautilus-ubuntu.sh (as your user) —
# it reinstalls the overlay on top; the stock package is never touched.
# `apt build-dep nautilus` needs deb-src entries enabled first.
if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
else
    sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list
fi
apt-get update
apt-get build-dep -y nautilus
apt-get install -y nautilus   # keep stock installed for runtime deps, then shadow it

NAUTILUS_BUILD=$(mktemp -d)
meson setup "$NAUTILUS_BUILD" "$REPO_DIR/applications/nautilus-fork/nautilus" \
    --prefix=/usr/local \
    -D docs=false \
    -D packagekit=false \
    -D selinux=false
meson compile -C "$NAUTILUS_BUILD"
meson install -C "$NAUTILUS_BUILD"
rm -rf "$NAUTILUS_BUILD"
ldconfig
glib-compile-schemas /usr/local/share/glib-2.0/schemas 2>/dev/null || true

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
    [org.gnome.Terminal.desktop]=org.gnome.Terminal.svg
    [org.gnome.Evince.desktop]=org.gnome.Evince.svg
    [org.gnome.Papers.desktop]=org.gnome.Papers.svg
    [org.gnome.Software.desktop]=org.gnome.Software.svg
)
for desktop in "${!ICON_OVERRIDES[@]}"; do
    src="/usr/share/applications/$desktop"
    [[ -f "$src" ]] || continue
    cp "$src" "/usr/local/share/applications/$desktop"
    sed -i "s|^Icon=.*|Icon=$ICON_DIR/${ICON_OVERRIDES[$desktop]}|" \
        "/usr/local/share/applications/$desktop"
done

# The Nautilus fork's .desktop already lives in /usr/local — repoint it too.
sed -i "s|^Icon=.*|Icon=$ICON_DIR/org.gnome.Nautilus.svg|" \
    /usr/local/share/applications/org.gnome.Nautilus.desktop

update-desktop-database /usr/local/share/applications 2>/dev/null || true

echo
echo "INSTALLATION COMPLETE"
echo " - Reboot to apply the silent/fast boot changes."
echo " - Log out and back in for the docker group to take effect."
