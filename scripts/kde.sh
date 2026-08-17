#!/bin/bash
# KDE Plasma variant of install.sh — run on a fresh Arch install as the normal
# user (./scripts/kde.sh). Same fresh-machine assumptions as install.sh: never
# uninstalls prior setups, destructive in places, ends with a reboot.
#
# Deliberate differences from install.sh (the Hyprland + Noctalia desktop) —
# don't "fix" these back:
# - Plasma instead of Hyprland; nothing Noctalia/Quickshell is installed.
# - Dolphin is the file manager — the vendored Nautilus fork is the Hyprland
#   setup's only; no IgnorePkg edit here.
# - Konsole (KDE default) instead of alacritty; KDE apps for the rest:
#   Gwenview (Loupe), KCalc (Calculator), Ark (File Roller), Okular (Evince),
#   Kate (Text Editor), Spectacle (grim/slurp).
# - SDDM is the login path — no tty1 autologin / .zprofile exec (and no
#   breezex-cursor-theme; Plasma keeps stock Breeze).
# - AC-plug power-profile switching, idle/lock, rfkill and clipboard handling
#   all stay with Plasma (PowerDevil/KScreenLocker/Klipper) — none of
#   install.sh's udev rules, systemd user units or joystick-wake carry over.
# - No QT_SCALE_FACTOR .desktop overrides: Plasma scales Qt apps natively,
#   so the 125% hack would double-scale OBS/qBittorrent here.
# - Only the desktop-agnostic piece of config/ is installed (vim) — the rest
#   (hypr, quickshell, noctalia, gtk-3.0, alacritty, the systemd user units)
#   belongs to the Hyprland desktop.
set -e

USERNAME=$(logname)
# The script lives in scripts/ — the repo root is one level up.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# System-level steps below use sudo, but the script itself must run as the
# normal user — yay and makepkg refuse to build packages as root.
if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user (./scripts/kde.sh), not with sudo — it asks for the password itself." >&2
    exit 1
fi

# Ask for the sudo password once, up front, and keep the credential cache
# fresh in the background — the pacman/yay steps outlast sudo's 15-minute
# timeout, and a mid-run re-prompt would stall the install.
sudo -v
( while kill -0 "$$" 2>/dev/null; do sleep 60; sudo -n -v; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

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

# plasma-meta brings the full desktop (powerdevil, bluedevil, kscreen,
# breeze-gtk/kde-gtk-config for GTK apps, xdg-desktop-portal-kde, Discover);
# kio-extras replaces gvfs-mtp (MTP/network in Dolphin), ffmpegthumbs and
# kdegraphics-thumbnailers give Dolphin video/PDF thumbnails.
sudo pacman -S --noconfirm --needed \
    plasma-meta \
    sddm \
    dolphin \
    konsole \
    ark \
    gwenview \
    kcalc \
    okular \
    kate \
    spectacle \
    kio-extras \
    kio-admin \
    ffmpegthumbs \
    kdegraphics-thumbnailers \
    power-profiles-daemon \
    jq \
    obs-studio \
    qbittorrent \
    ffmpeg \
    libreoffice-fresh \
    ntfsprogs \
    xdg-user-dirs

# SDDM handles login — deliberately no autologin (unlike the Hyprland
# setup's tty1 agetty autologin).
sudo systemctl enable sddm.service

bash -c "curl -fsSL https://claude.ai/install.sh | bash"

# GTK's Vulkan renderer (4.16+) enumerates every GPU at startup, waking the
# runtime-suspended NVIDIA dGPU — an ~1.5 s stall on each GTK4 app launch even
# though rendering happens on the Intel iGPU. /etc/environment (PAM) covers
# the whole session, including dbus-/systemd-activated apps.
# Replace-or-append so a stale hand-set value gets corrected on re-runs; the
# leading \n keeps the entry intact even if the file lacks a trailing newline.
if grep -q '^GDK_DISABLE=' /etc/environment 2>/dev/null; then
    sudo sed -i 's/^GDK_DISABLE=.*/GDK_DISABLE=vulkan/' /etc/environment
else
    printf '\nGDK_DISABLE=vulkan\n' | sudo tee -a /etc/environment >/dev/null
fi

# Don't power the Bluetooth adapter on at boot; toggle it from the Plasma
# applet when needed. (No rfkill-unblock unit here: Plasma manages rfkill
# itself — the unit in install.sh exists for Noctalia's airplane mode.)
if [[ -f /etc/bluetooth/main.conf ]]; then
    if grep -q '^#*AutoEnable=' /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#*AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
    else
        printf '\n[Policy]\nAutoEnable=false\n' | sudo tee -a /etc/bluetooth/main.conf >/dev/null
    fi
fi

APPS_DIR="/home/$USERNAME/.local/share/applications"
mkdir -p "$APPS_DIR"

files=(
    avahi-discover.desktop
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
    remote-viewer.desktop
    uuctl.desktop
)

for file in "${files[@]}"; do
    src="/usr/share/applications/$file"
    dest="$APPS_DIR/$file"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        echo 'NoDisplay=true' >> "$dest"
    fi
done

# LibreOffice: only Writer, Calc and Impress stay visible in the launcher.
# These .desktop files can't use the plain append above — they end with a
# [Desktop Action] section (so an appended key lands in the wrong section),
# and startcenter/math ship an explicit NoDisplay=false that overrides any
# earlier NoDisplay=true (GKeyFile takes the last occurrence of a key).
# NoDisplay=true must therefore be the last key of [Desktop Entry], i.e.
# inserted right before the Actions= line.
for src in /usr/share/applications/libreoffice-*.desktop; do
    [[ -f "$src" ]] || continue
    name=$(basename "$src")
    case "$name" in
        libreoffice-writer.desktop|libreoffice-calc.desktop|libreoffice-impress.desktop)
            continue ;;
    esac
    dest="$APPS_DIR/$name"
    cp "$src" "$dest"
    if grep -q '^Actions=' "$dest"; then
        sed -i '/^Actions=/i NoDisplay=true' "$dest"
    else
        echo 'NoDisplay=true' >> "$dest"
    fi
done

sudo cp "$REPO_DIR"/assets/icons/* /usr/share/icons/hicolor/scalable/apps/

# extract-audio: pulls audio out of videos as MP3 (Resolve on Linux can't
# decode AAC, so H.264 clips import silent without it). ffmpeg is in the
# pacman list above. /usr/local/bin so it works from any shell/directory.
sudo install -Dm755 "$REPO_DIR/assets/bin/extract-audio" /usr/local/bin/extract-audio

sudo mkdir -p /usr/share/fonts/fira
sudo cp "$REPO_DIR"/assets/fira/*.ttf /usr/share/fonts/fira/
sudo cp "$REPO_DIR"/assets/fonts/* /usr/share/fonts/
sudo fc-cache -f

# Only the desktop-agnostic piece of config/ — the rest is the Hyprland
# desktop's and stays out.
if [[ -d "$REPO_DIR/config/vim" ]]; then
    mkdir -p "/home/$USERNAME/.config"
    cp -r "$REPO_DIR/config/vim" "/home/$USERNAME/.config/"
fi

# Interface font: Fira Sans (Book), same as the Hyprland/GNOME setups set via
# gsettings. Plasma reads these from ~/.config/kdeglobals on login, so writing
# them from the tty here just works. QFont string fields: family, size, then
# defaults; the trailing "Book" is the style name (falls back to Regular if
# the face is missing). The fixed-width font stays Plasma's default.
FIRA='Fira Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Book'
kwriteconfig6 --file kdeglobals --group General --key font "$FIRA"
kwriteconfig6 --file kdeglobals --group General --key menuFont "$FIRA"
kwriteconfig6 --file kdeglobals --group General --key toolBarFont "$FIRA"
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont 'Fira Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Book'
kwriteconfig6 --file kdeglobals --group WM --key activeFont "$FIRA"

# ~/.face for apps that read it, ~/.face.icon for SDDM/Plasma's user avatar.
cp "$REPO_DIR/assets/profile.png" "/home/$USERNAME/.face"
cp "$REPO_DIR/assets/profile.png" "/home/$USERNAME/.face.icon"

xdg-mime default org.kde.gwenview.desktop image/jpeg
xdg-mime default org.kde.gwenview.desktop image/png
xdg-mime default org.kde.gwenview.desktop image/webp

xdg-mime default org.kde.kate.desktop text/plain
xdg-mime default org.kde.kate.desktop application/x-shellscript

xdg-user-dirs-update

bash -c "cd '$REPO_DIR/applications/music' && echo Y | ./install.sh"

rm -f "/home/$USERNAME/.gnupg/public-keys.d/pubring.db.lock"

# Spotify with ad blocking (AUR). Its build imports upstream GPG keys, which
# needs the stale pubring lock removed first (done above) — still best-effort:
# on failure just carry on to the reboot. On success the package pulls in
# plain spotify too, so hide spotify.desktop and present the adblock entry as
# plain "Spotify".
if yay -S --noconfirm --needed spotify-adblock; then
    if [[ -f /usr/share/applications/spotify.desktop ]]; then
        cp /usr/share/applications/spotify.desktop "$APPS_DIR/spotify.desktop"
        echo 'NoDisplay=true' >> "$APPS_DIR/spotify.desktop"
    fi
    if [[ -f /usr/share/applications/spotify-adblock.desktop ]]; then
        cp /usr/share/applications/spotify-adblock.desktop "$APPS_DIR/spotify-adblock.desktop"
        sed -i 's/^Name=.*/Name=Spotify/' "$APPS_DIR/spotify-adblock.desktop"
    fi
else
    echo "spotify-adblock install failed — skipping, continuing to reboot." >&2
fi

# After every .desktop override is in place (including spotify's above).
update-desktop-database "$APPS_DIR"

sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


sudo reboot
