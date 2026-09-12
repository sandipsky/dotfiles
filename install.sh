#!/bin/bash
set -e

USERNAME=$(logname)

# System-level steps below use sudo, but the script itself must run as the
# normal user — yay and makepkg refuse to build packages as root.
if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user (./install.sh), not with sudo — it asks for the password itself." >&2
    exit 1
fi

# All interactive input happens here, before the long unattended run.
read -rp "Install Plymouth boot splash? (y/n): " INSTALL_PLYMOUTH
read -rp "Install SDDM login screen (Elegant theme) instead of direct login into Hyprland? (y/n): " INSTALL_SDDM
read -rp "Install LibreOffice (Writer, Calc, Impress)? (y/n): " INSTALL_OFFICE
read -rp "Install VirtualBox (VM host, with the guest-additions ISO)? (y/n): " INSTALL_VIRTUALBOX
read -rp "Clone your GitHub projects into ~/Projects? (needs the secrets password) (y/n): " CLONE_PROJECTS

# The clone script carries a GitHub token, so the repo only holds it encrypted
# (scripts/github.sh.enc, see scripts/secrets.sh). Take the password now and
# verify it, so a typo can't surface as a failure an hour into the run.
SECRET_PASSWORD=
if [[ "${CLONE_PROJECTS,,}" == y* ]]; then
    for _ in 1 2 3; do
        read -rsp "Secrets password (empty to skip cloning): " SECRET_PASSWORD; echo
        [[ -z "$SECRET_PASSWORD" ]] && break
        SECRET_PASSWORD="$SECRET_PASSWORD" ./scripts/secrets.sh check && break
        echo "Wrong password." >&2
        SECRET_PASSWORD=
    done
    if [[ -z "$SECRET_PASSWORD" ]]; then
        echo "Skipping the project clones." >&2
        CLONE_PROJECTS=n
    fi
fi

# Ask for the sudo password once, up front, and keep the credential cache
# fresh in the background — the pacman/yay/makepkg steps outlast sudo's
# 15-minute timeout, and a mid-run re-prompt would stall the install.
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

sudo pacman -S --noconfirm --needed \
    hyprland \
    hyprpicker \
    wl-clipboard \
    cliphist \
    wtype \
    xdg-desktop-portal-hyprland \
    hyprsunset \
    power-profiles-daemon \
    polkit-gnome \
    blueman \
    jq \
    git \
    alacritty \
    xdg-user-dirs-gtk \
    obs-studio \
    qbittorrent \
    brightnessctl \
    ffmpeg \
    luajit \
    grim \
    slurp \
    gnome-calculator \
    evince \
    loupe \
    file-roller \
    gnome-text-editor \
    gvfs-mtp \
    ntfsprogs \
    gnome-themes-extra \
    adwaita-icon-theme \
    uwsm

yay -S --noconfirm --needed \
    breezex-cursor-theme

sudo -u "$USERNAME" -H bash -c "curl -fsSL https://claude.ai/install.sh | bash"

# hypr-shell — the GTK4 bar/shell (bar, launcher, control center, notifications,
# lock/idle, night light, wallpaper, OSDs). Cloned fresh from its GitHub repo
# (public, so no token) into a temp dir and built from there — the repo moves
# too fast to keep a vendored snapshot in sync, so this step needs network
# (it just ran pacman/yay, so that's already a given). Its own install.sh
# installs the pacman build deps it is missing (gtkmm-4.0, gtk4-layer-shell,
# libadwaita, ...) and builds into ~/.local (binaries, icon fonts, desktop
# entry); autostart.lua and the keybinds call /home/$USERNAME/.local/bin/hypr-shell
# by absolute path. The throwaway clone is removed afterwards; the dev checkout
# at ~/Projects/hypr-shell comes from the project-clone step at the end.
HYPR_SHELL_REPO=https://github.com/sandipsky/hypr-shell
BUILD_DIR=$(sudo -u "$USERNAME" mktemp -d)
sudo -u "$USERNAME" git clone --depth 1 "$HYPR_SHELL_REPO" "$BUILD_DIR/hypr-shell"
(cd "$BUILD_DIR/hypr-shell" && sudo -u "$USERNAME" -H ./install.sh)
rm -rf "$BUILD_DIR"

# Nautilus comes only from the local fork vendored in applications/nautilus-fork/
# (upstream source + local patches, see docs/nautilus-patches.md), built from
# the repo tree — the official package is never installed; pacman -U resolves
# the fork's runtime deps from the repos itself. IgnorePkg then keeps
# pacman -Syu from replacing the fork with a newer repo package — upgrades
# happen by bumping the vendored tree (see scripts/rebuild-nautilus.sh).
BUILD_DIR=$(sudo -u "$USERNAME" mktemp -d)
sudo -u "$USERNAME" cp -r applications/nautilus-fork/. "$BUILD_DIR/"
(cd "$BUILD_DIR" && sudo -u "$USERNAME" makepkg -s --noconfirm)
sudo pacman -U --noconfirm "$BUILD_DIR"/nautilus-*.pkg.tar.zst "$BUILD_DIR"/libnautilus-extension-*.pkg.tar.zst
rm -rf "$BUILD_DIR"
if ! grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*nautilus' /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a IgnorePkg = nautilus libnautilus-extension' /etc/pacman.conf
fi

sudo cp assets/99-power.rules /etc/udev/rules.d/99-power.rules
sudo sed -i "s/USERNAME/$USERNAME/g" /etc/udev/rules.d/99-power.rules

# GTK's Vulkan renderer (4.16+) enumerates every GPU at startup, waking the
# runtime-suspended NVIDIA dGPU — an ~1.5 s stall on each GTK4 app launch even
# though rendering happens on the Intel iGPU. /etc/environment (PAM) covers
# the whole session — Hyprland, its children, AND dbus-/systemd-activated
# apps — so this is the single place the fix lives (not environment.lua,
# which would miss the dbus-activated ones).
# Replace-or-append so a stale hand-set value gets corrected on re-runs; the
# leading \n keeps the entry intact even if the file lacks a trailing newline.
if grep -q '^GDK_DISABLE=' /etc/environment 2>/dev/null; then
    sudo sed -i 's/^GDK_DISABLE=.*/GDK_DISABLE=vulkan/' /etc/environment
else
    printf '\nGDK_DISABLE=vulkan\n' | sudo tee -a /etc/environment >/dev/null
fi

if [[ -f /etc/bluetooth/main.conf ]]; then
    if grep -q '^#*AutoEnable=' /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#*AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
    else
        printf '\n[Policy]\nAutoEnable=false\n' | sudo tee -a /etc/bluetooth/main.conf >/dev/null
    fi
fi

# systemd-rfkill persists rfkill soft blocks across reboots (e.g. one left by
# an airplane-mode toggle), and BlueZ can't power a blocked adapter — the bar
# widget's Bluetooth toggle would silently fail forever. Clear the block every
# boot; the adapter still stays off until toggled (AutoEnable=false above).
sudo tee /etc/systemd/system/bluetooth-rfkill-unblock.service >/dev/null <<'EOF'
[Unit]
Description=Clear persisted Bluetooth rfkill soft block
After=systemd-rfkill.service

[Service]
Type=oneshot
ExecStart=/usr/bin/rfkill unblock bluetooth

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable bluetooth-rfkill-unblock.service

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

# LibreOffice (optional). scripts/office.sh installs libreoffice-fresh and
# hides everything but Writer, Calc and Impress from the launcher (NoDisplay
# overrides in ~/.local/share/applications — see the script for why they
# can't use the plain append above). It can also add or remove the suite
# later on the running system: ./scripts/office.sh install|remove|status
if [[ "${INSTALL_OFFICE,,}" == y* ]]; then
    ./scripts/office.sh install
fi

# VirtualBox (optional). scripts/virtualbox.sh installs virtualbox, the dkms
# host modules (Arch no longer ships prebuilt ones) with the headers for every
# installed kernel, and the guest-additions ISO, then adds the user to
# vboxusers for USB passthrough and writes a virtualbox.desktop override
# launching it at 125% (QT_SCALE_FACTOR, same as the OBS/qBittorrent loop
# below). It can also add or remove it later on the running system:
# ./scripts/virtualbox.sh install|remove|status
if [[ "${INSTALL_VIRTUALBOX,,}" == y* ]]; then
    ./scripts/virtualbox.sh install
fi

# OBS Studio and qBittorrent (Qt apps) render too small — launch them at
# 125% scaling via local .desktop overrides. (VirtualBox gets the same
# treatment from scripts/virtualbox.sh when it is installed.)
for file in com.obsproject.Studio.desktop org.qbittorrent.qBittorrent.desktop; do
    src="/usr/share/applications/$file"
    dest="$APPS_DIR/$file"
    if [[ -f "$src" ]]; then
        sudo -u "$USERNAME" cp "$src" "$dest"
        sudo -u "$USERNAME" sed -i 's|^Exec=|Exec=env QT_SCALE_FACTOR=1.25 |' "$dest"
    fi
done

sudo cp assets/icons/* /usr/share/icons/hicolor/scalable/apps/

# extract-audio: pulls audio out of videos as MP3 (Resolve on Linux can't
# decode AAC, so H.264 clips import silent without it). ffmpeg is in the
# pacman list above. /usr/local/bin so it works from any shell/directory.
sudo install -Dm755 assets/bin/extract-audio /usr/local/bin/extract-audio

sudo mkdir -p /usr/share/fonts
sudo cp assets/fonts/* /usr/share/fonts/
sudo fc-cache -f

sudo -u "$USERNAME" cp -r config/* "/home/$USERNAME/.config/"

# Plymouth boot splash (optional). arch.sh already boots quiet with early KMS
# (i915 + nvidia in MODULES, systemd hook, systemd-boot entry), so this is
# just the hook, the `splash` kernel arg and a theme: the default theme minus
# the Arch logo under the spinner, boot-only (no shutdown splash). It all
# lives in scripts/plymouth.sh, which can also add or remove it later on the
# running system: ./scripts/plymouth.sh install|remove|status
if [[ "${INSTALL_PLYMOUTH,,}" == y* ]]; then
    ./scripts/plymouth.sh install
fi

# Login path (optional SDDM). Default is direct login: tty1 autologin via an
# agetty override, then the login profile execs Hyprland through uwsm. With
# SDDM chosen, scripts/sddm.sh installs sddm + the Elegant
# theme, enables sddm.service and skips/removes those two direct-login
# pieces (it can also switch a running system either way later:
# ./scripts/sddm.sh install|uninstall|status). Its `uninstall`
# re-creates the override and profile block below — keep them in sync.
if [[ "${INSTALL_SDDM,,}" == y* ]]; then
    ./scripts/sddm.sh install
else
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --skip-login --nonewline --noissue --noclear %I \$TERM
Type=idle
EOF

    LOGIN_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
    if [[ "$(basename "$LOGIN_SHELL")" == "zsh" ]]; then
        AUTOSTART_PROFILE="/home/$USERNAME/.zprofile"
    else
        AUTOSTART_PROFILE="/home/$USERNAME/.bash_profile"
    fi
    tee "$AUTOSTART_PROFILE" >/dev/null <<'EOF'
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
    if uwsm check may-start; then
        exec uwsm start hyprland.desktop >/dev/null 2>&1
    fi
fi
EOF
fi

# the Hyprland Lua config and hypr-shell's config.json carry absolute paths
for f in hypr/conf/keybinds.lua hypr/conf/autostart.lua hypr-shell/config.json; do
    sudo -u "$USERNAME" sed -i "s|USERNAME|$USERNAME|g" "/home/$USERNAME/.config/$f"
done
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

# PDFs always open in Evince, whether or not LibreOffice was installed above
# (LibreOffice Draw registers itself for application/pdf and would otherwise
# grab the association).
sudo -u "$USERNAME" -H xdg-mime default org.gnome.Evince.desktop application/pdf

sudo -u "$USERNAME" -H xdg-user-dirs-update

# ~/Projects as an extra XDG user dir. xdg-user-dirs-update only creates the
# standard eight, but keeps any local additions to user-dirs.dirs, so the
# line survives its later runs.
USER_DIRS="/home/$USERNAME/.config/user-dirs.dirs"
if ! grep -q '^XDG_PROJECTS_DIR=' "$USER_DIRS" 2>/dev/null; then
    echo 'XDG_PROJECTS_DIR="$HOME/Projects"' >> "$USER_DIRS"
fi
mkdir -p "/home/$USERNAME/Projects"

# Sidebar shortcuts. Nautilus lists the user folders from the GTK bookmarks
# file; on GNOME xdg-user-dirs-gtk-update seeds it at login, but its autostart
# entry is OnlyShowIn=GNOME/XFCE/..., so under Hyprland the sidebar stays at
# Home/Starred/Network/Trash unless we write the bookmarks ourselves.
# Append-if-missing, so bookmarks added later in Nautilus are kept.
BOOKMARKS="/home/$USERNAME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$BOOKMARKS")"
touch "$BOOKMARKS"
for dir in Documents Downloads Music Pictures Videos Projects; do
    mkdir -p "/home/$USERNAME/$dir"
    grep -qxF "file:///home/$USERNAME/$dir" "$BOOKMARKS" || echo "file:///home/$USERNAME/$dir" >> "$BOOKMARKS"
done

# Decrypts scripts/github.sh.enc with the password taken up front and runs it
# — it clones the GitHub repos into ~/Projects, skipping existing checkouts.
if [[ "${CLONE_PROJECTS,,}" == y* ]]; then
    SECRET_PASSWORD="$SECRET_PASSWORD" ./scripts/secrets.sh run \
        || echo "Some project clones failed — re-run ./scripts/secrets.sh run later." >&2
fi

sudo -u "$USERNAME" -H bash -c "cd '$PWD/applications/music' && echo Y | ./install.sh"

sudo -u "$USERNAME" rm -f /home/$USERNAME/.gnupg/public-keys.d/pubring.db.lock

# Spotify with ad blocking (AUR). Its build imports upstream GPG keys, which
# needs the stale pubring lock removed first (done above) — still best-effort:
# on failure just carry on to the reboot. On success the package pulls in
# plain spotify too, so hide spotify.desktop and present the adblock entry as
# plain "Spotify".
if sudo -u "$USERNAME" yay -S --noconfirm --needed spotify-adblock; then
    if [[ -f /usr/share/applications/spotify.desktop ]]; then
        sudo -u "$USERNAME" cp /usr/share/applications/spotify.desktop "$APPS_DIR/spotify.desktop"
        sudo -u "$USERNAME" bash -c "echo 'NoDisplay=true' >> '$APPS_DIR/spotify.desktop'"
    fi
    if [[ -f /usr/share/applications/spotify-adblock.desktop ]]; then
        sudo -u "$USERNAME" cp /usr/share/applications/spotify-adblock.desktop "$APPS_DIR/spotify-adblock.desktop"
        sudo -u "$USERNAME" sed -i 's/^Name=.*/Name=Spotify/' "$APPS_DIR/spotify-adblock.desktop"
    fi
else
    echo "spotify-adblock install failed — skipping, continuing to reboot." >&2
fi

# After every .desktop override is in place (including spotify's above).
sudo -u "$USERNAME" update-desktop-database "$APPS_DIR"

sudo sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


sudo reboot