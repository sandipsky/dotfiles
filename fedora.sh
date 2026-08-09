#!/usr/bin/env bash
# Post-install setup for a FRESH **Fedora Workstation** (GNOME) install — the
# Fedora counterpart of ubuntu.sh. GNOME stays the desktop; nothing
# Hyprland/Noctalia is installed. Run it from the repo root as your normal
# user:
#
#   ./fedora.sh
#
# Like the other scripts it targets a fresh machine, never uninstalls prior
# setups, is destructive in places (writes /etc units and udev-adjacent
# configs, tunes /etc/dnf/dnf.conf and GRUB, edits your login shell) and ends
# with a reboot.
#
# What it sets up, tuned for this machine — an ASUS TUF F15 (i5-10300H +
# GTX 1650 hybrid graphics):
# - NVIDIA driver (RPM Fusion akmod) with runtime D3 power management, and
#   the Secure Boot MOK signing flow (mokutil prompts for a one-time
#   password mid-run — expected, not a hang). Skipped inside any VM;
#   VirtualBox guests get the guest additions instead.
# - Power tuning: 80% battery charge threshold, audio codec suspend, zram
#   sized like the Arch box, TRIM, VA-API on the iGPU.
# - Boot: hidden GRUB (Windows boots via the firmware boot menu — Esc on
#   ASUS), quiet/fast kernel args. Workstation already shows Plymouth's bgrt
#   splash, so there is no splash work to do.
# - Chrome + VS Code from the vendors' rpm repos; zsh + starship as the login
#   shell; the stock terminal (Ptyxis) stays but wears GNOME Terminal's
#   icon; git identity (only when unset). The dev stack (node/JDK/Angular
#   CLI) and the gaming stack (wine/winetricks/lutris) are each prompted up
#   front.
# - GNOME Shell extensions: Dash to Dock (Fedora's package), "Disable
#   Workspace Switcher Overlay" (e.g.o #6358, fetched for the running Shell)
#   and the Extensions app; the stock system extensions (Apps Menu,
#   Background Logo, Launch New Instance, Places, Window List) and a set of
#   preinstalled GNOME apps (Contacts, Help, Boxes, Tour, Weather, Maps,
#   Connections, Document Scanner, the stock audio/video/camera apps) are
#   removed.
# - Custom app icons, extract-audio, the Fira Sans + Microsoft fonts,
#   Spotify with adblock, and the meson-built music app into ~/.local.
#   Nautilus is Workstation's stock package (the vendored fork is Arch-only).
# - Optional NTFS data partition mounted at /mnt/HOME via fstab (prompted up
#   front, same as arch.sh/ubuntu.sh; blank to skip).
set -e

USERNAME=$(logname)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=()

info() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command against the user's session bus when one exists, else in a
# throwaway bus — gsettings/dconf/gnome-extensions all need one.
as_session() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        "$@"
    else
        dbus-run-session -- "$@"
    fi
}

# System-level steps below use sudo, but the script itself must run as the
# normal user — the source builds compile in the user's own temp dirs and
# the Claude Code installer refuses to run as root.
if [[ $EUID -eq 0 ]]; then
    die "Run this as your normal user (./fedora.sh), not with sudo — it asks for the password itself."
fi

. /etc/os-release
[[ "${ID:-}" == "fedora" ]] || die "This is the Fedora script — /etc/os-release says ID=${ID:-unknown}."
FEDORA_REL=$(rpm -E %fedora)

# "oracle" = VirtualBox; systemd-detect-virt exits non-zero on bare metal.
# In any VM the NVIDIA driver and its power tweaks are skipped.
VIRT=$(systemd-detect-virt 2>/dev/null) || VIRT=none

# Ask for the sudo password once, up front, and keep the credential cache
# fresh in the background — the dnf and compile steps outlast sudo's default
# timeout, and a mid-run re-prompt would stall the install.
sudo -v
( while kill -0 "$$" 2>/dev/null; do sleep 60; sudo -n -v; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

### -------- PROMPTS (everything interactive happens up front) --------
# Only the Secure Boot MOK password can still ask mid-run.
echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
echo
read -rp "NTFS partition to mount at /mnt/HOME (e.g. /dev/nvme1n1p1, blank to skip): " NTFS_DRIVE
read -rp "Install the development stack (node, JDK, Angular CLI)? [Y/n]: " INSTALL_DEV
read -rp "Install the gaming stack (wine, winetricks, lutris)? [Y/n]: " INSTALL_GAMING

### -------- DNS --------
# The GLX router's first DHCP DNS server (110.44.112.200) is dead and glibc
# stalls 5 s per lookup on it — pin known-good resolvers globally
# (Domains=~. outranks any network's DHCP DNS) via systemd-resolved.
info "Pinning DNS resolvers"
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

### -------- DNF TUNING --------
# dnf downloads serially from one mirror by default; values already present
# are left alone.
DNF_CONF=/etc/dnf/dnf.conf
sudo mkdir -p /etc/dnf
sudo touch "$DNF_CONF"
grep -q '^\[main\]' "$DNF_CONF" || printf '[main]\n' | sudo tee -a "$DNF_CONF" >/dev/null
for setting in max_parallel_downloads=10 fastestmirror=True; do
    key=${setting%%=*}
    if grep -qE "^[[:space:]]*$key[[:space:]]*=" "$DNF_CONF"; then
        echo "    dnf.conf already sets $key — leaving it as configured"
    else
        sudo sed -i "/^\[main\]/a $setting" "$DNF_CONF"
        echo "    dnf.conf: added $setting"
    fi
done

### -------- REPOS --------
info "Refreshing the base system"
sudo dnf upgrade -y --refresh

# dnf5-plugins provides `dnf builddep` (dnf-plugins-core on dnf4).
sudo dnf install -y dnf5-plugins || sudo dnf install -y dnf-plugins-core

# --skip-unavailable keeps one renamed/absent package from failing a whole
# transaction; critical commands are verified explicitly further down.
DNF_SKIP=--skip-unavailable
if ! dnf install --help 2>&1 | grep -q -- '--skip-unavailable'; then
    DNF_SKIP=--setopt=strict=0
fi
dnfi() { sudo dnf install -y "$DNF_SKIP" "$@"; }

# RPM Fusion, for the NVIDIA driver, the full ffmpeg build (extract-audio
# wants a dependable MP3 encoder) and the gaming stack's 32-bit GPU bits.
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_REL.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_REL.noarch.rpm" \
        || warn "RPM Fusion setup failed — NVIDIA/ffmpeg/Spotify steps will degrade."
fi

### -------- PACKAGES --------
# Only what Workstation lacks; everything GNOME already ships stays stock.
info "Installing packages"
dnfi \
    git \
    jq \
    curl \
    obs-studio \
    qbittorrent \
    vlc \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    file-roller \
    gvfs-mtp \
    ntfs-3g \
    ntfsprogs

# Full ffmpeg (RPM Fusion) replacing Workstation's ffmpeg-free.
sudo dnf install -y --allowerasing ffmpeg || dnfi ffmpeg-free

# VLC itself is in Fedora proper; its full-codec plugin set lives in RPM
# Fusion. Best-effort — stock VLC still plays the free formats without it.
sudo dnf install -y vlc-plugins-freeworld \
    || warn "vlc-plugins-freeworld not installed — VLC keeps the free-codec set."

# --skip-unavailable makes a renamed package a warning, not a failure — so
# verify the commands themselves rather than trusting the package names.
MISSING=()
for cmd in git jq curl nmcli bluetoothctl gsettings dconf \
           gnome-extensions update-desktop-database fc-cache xdg-mime; do
    have "$cmd" || MISSING+=("$cmd")
done
if (( ${#MISSING[@]} )); then
    die "These commands are still missing after the package step: ${MISSING[*]}
    Nothing else has been configured yet. Find the Fedora $FEDORA_REL package that
    provides each (dnf provides '*/bin/<cmd>'), install it, then re-run ./fedora.sh."
fi
for cmd in ffmpeg dbus-run-session; do
    have "$cmd" || warn "$cmd is missing — the features using it will be degraded."
done

### -------- CLAUDE CODE --------
info "Installing Claude Code"
curl -fsSL https://claude.ai/install.sh | bash || { warn "Claude Code install failed."; FAILURES+=("Claude Code"); }

### -------- NVIDIA (GTX 1650 + i5-10300H hybrid graphics) --------
# RPM Fusion's akmod-nvidia rebuilds the kernel module automatically on every
# kernel update. The TUF F15's panel is wired to the Intel iGPU — GNOME
# renders on i915 and the dGPU is offload-only. The runtime-PM modprobe
# options and udev rules let the card power off completely (D3cold) while
# nothing uses it — the single biggest battery win on this machine.
NVIDIA_OK=0
install_nvidia() {
    rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 || return 1
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda || return 1
    # -power ships the nvidia-suspend/resume units; libva-nvidia-driver adds
    # VA-API on the dGPU; switcheroo-control backs GNOME's own
    # "Launch using Discrete Graphics Card" context-menu entry.
    dnfi xorg-x11-drv-nvidia-power libva-nvidia-driver switcheroo-control

    # Same knobs as arch.sh's nvidia-pm.conf. The S0ix flag is ignored on
    # S3-only firmware; PreserveVideoMemoryAllocations makes suspend/resume
    # reliable on Wayland.
    sudo tee /etc/modprobe.d/nvidia-pm.conf >/dev/null <<'EOF'
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia NVreg_EnableS0ixPowerManagement=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF

    # add|bind: matching "add" applies the rule on the udev coldplug replay.
    sudo tee /etc/udev/rules.d/80-nvidia-pm.rules >/dev/null <<'EOF'
# Enable runtime PM for the NVIDIA GPU and its HDMI audio function
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"

# Revert to always-on when the driver unbinds
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="on"
EOF
    sudo restorecon -F /etc/modprobe.d/nvidia-pm.conf /etc/udev/rules.d/80-nvidia-pm.rules 2>/dev/null || true

    sudo systemctl enable nvidia-suspend.service nvidia-resume.service 2>/dev/null || true
    sudo systemctl enable switcheroo-control.service 2>/dev/null || true

    # Dual-booting Windows usually means Secure Boot is ON, and an unsigned
    # akmod module won't load. Generate the akmods signing key (akmods signs
    # every build with it from then on) and queue it for MOK enrollment.
    dnfi mokutil openssl
    if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        info "Secure Boot is enabled — setting up module signing"
        sudo kmodgenca -a || true
        warn "mokutil now asks you to invent a one-time password — you'll re-enter it on the blue 'MOK management' screen right after the reboot (Enroll MOK -> Continue -> reboot)."
        sudo mokutil --import /etc/pki/akmods/certs/public_key.der \
            || warn "MOK import failed — the NVIDIA module won't load until Secure Boot is disabled in the BIOS or the key is enrolled manually."
    fi

    # Build the module for every installed kernel NOW — the upgrade at the top
    # may have installed a newer kernel than the running one, and without this
    # the first boot has no nvidia module until akmods.service catches up.
    sudo akmods --force || return 1
}
if [[ "$VIRT" != "none" ]]; then
    info "Virtual machine detected ($VIRT) — skipping the NVIDIA driver and its power tweaks"
else
    info "Installing the NVIDIA driver (RPM Fusion akmod)"
    if install_nvidia; then
        NVIDIA_OK=1
    else
        warn "NVIDIA driver install failed — the desktop still runs fine on the Intel iGPU."
        FAILURES+=("NVIDIA driver (akmod-nvidia)")
    fi
fi

### -------- GTK4 dGPU LAUNCH STALL --------
# GTK's Vulkan renderer (4.16+) enumerates every GPU at startup, waking the
# runtime-suspended NVIDIA dGPU — an ~1.5 s stall on each GTK4 app launch
# even though rendering happens on the Intel iGPU anyway. Disable GTK's
# Vulkan path session-wide. Set unconditionally (not inside install_nvidia):
# it's inert without the dGPU, and this way a later manual driver install
# can't reintroduce the stall.
# Replace-or-append so a stale hand-set value gets corrected on re-runs; the
# leading \n keeps the entry intact even if the file lacks a trailing newline.
# No restorecon: appending never changes the existing file's SELinux label.
if grep -q '^GDK_DISABLE=' /etc/environment 2>/dev/null; then
    sudo sed -i 's/^GDK_DISABLE=.*/GDK_DISABLE=vulkan/' /etc/environment
else
    printf '\nGDK_DISABLE=vulkan\n' | sudo tee -a /etc/environment >/dev/null
fi

### -------- VIRTUALBOX GUEST ADDITIONS --------
if [[ "$VIRT" == "oracle" || "$VIRT" == "virtualbox" ]]; then
    info "VirtualBox detected — installing guest additions"
    if dnfi virtualbox-guest-additions; then
        # Shared folders mount as root:vboxsf — same usermod arch.sh does.
        getent group vboxsf >/dev/null && sudo usermod -aG vboxsf "$USERNAME" || true
        sudo systemctl enable vboxservice.service 2>/dev/null || true
    else
        warn "Guest additions install failed — clipboard/resolution integration won't work."
        FAILURES+=("VirtualBox guest additions")
    fi
fi

### -------- POWER / PERFORMANCE --------
# arch.sh's laptop tuning, ported. Audio codec suspend is also a precondition
# for the dGPU reaching D3cold (the HDA function must idle). Profile switching
# stays with GNOME — the Hyprland setups' AC-plug udev automation is not
# carried over here.
info "Applying power/performance tuning"
sudo tee /etc/modprobe.d/audio-powersave.conf >/dev/null <<'EOF'
options snd_hda_intel power_save=1 power_save_controller=Y
EOF

sudo tee /etc/systemd/system/battery-charge-threshold.service >/dev/null <<'EOF'
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
sudo restorecon -F /etc/modprobe.d/audio-powersave.conf /etc/systemd/system/battery-charge-threshold.service 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl enable battery-charge-threshold.service
sudo systemctl start battery-charge-threshold.service || true

# Fedora enables zram by default; this pins arch.sh's sizing (ram/2, zstd).
dnfi zram-generator-defaults intel-media-driver libva-utils
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

sudo systemctl enable fstrim.timer 2>/dev/null || true

### -------- BOOT (hidden GRUB + kernel args) --------
# Workstation already shows Plymouth's bgrt splash — just hide the GRUB menu
# and add arch.sh's quiet/fast kernel args. Windows boots via the firmware
# boot menu (Esc on ASUS); os-prober stays off so it never reappears in (and
# slows down) grub2-mkconfig.
info "Hiding GRUB and applying kernel args"

# Append missing args to every installed kernel's BLS entry. New kernels
# inherit the default entry's args, so this persists across updates.
add_kernel_args() {
    local current missing=() arg
    current=$(sudo grubby --info=DEFAULT 2>/dev/null | sed -n 's/^args="\(.*\)"/\1/p' | head -1)
    for arg in "$@"; do
        [[ " $current " == *" $arg "* ]] || missing+=("$arg")
    done
    if (( ${#missing[@]} )); then
        sudo grubby --update-kernel=ALL --args="${missing[*]}"
    fi
}
KARGS=(rhgb quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0
       i915.fastboot=1 nowatchdog 8250.nr_uarts=0 mitigations=off)
if (( NVIDIA_OK )); then
    KARGS+=(nvidia-drm.modeset=1 rd.driver.blacklist=nouveau modprobe.blacklist=nouveau)
fi
add_kernel_args "${KARGS[@]}" \
    || { warn "Setting kernel args via grubby failed."; FAILURES+=("kernel args (grubby)"); }

set_grub_kv() {
    if sudo grep -q "^$1=" /etc/default/grub 2>/dev/null; then
        sudo sed -i "s|^$1=.*|$1=$2|" /etc/default/grub
    else
        echo "$1=$2" | sudo tee -a /etc/default/grub >/dev/null
    fi
}
set_grub_kv GRUB_TIMEOUT 0
set_grub_kv GRUB_TIMEOUT_STYLE hidden
set_grub_kv GRUB_DISABLE_OS_PROBER true
# On UEFI Fedora this is the real config; the ESP copy is a stub that loads it.
sudo grub2-mkconfig -o /boot/grub2/grub.cfg \
    || { warn "grub2-mkconfig failed — the GRUB menu may still show."; FAILURES+=("GRUB config regeneration"); }

# Biggest boot-time win: don't block boot waiting for the network.
sudo systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service 2>/dev/null || true

### -------- NTFS DRIVE --------
# Same /mnt/HOME arrangement as arch.sh and ubuntu.sh (ntfs-3g is in the
# package list above).
if [[ -n "${NTFS_DRIVE:-}" ]]; then
    NTFS_UUID=$(sudo blkid -s UUID -o value "$NTFS_DRIVE" 2>/dev/null) || NTFS_UUID=""
    if [[ -n "$NTFS_UUID" ]]; then
        sudo mkdir -p /mnt/HOME
        if ! grep -q "UUID=$NTFS_UUID" /etc/fstab; then
            echo "UUID=$NTFS_UUID /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0" \
                | sudo tee -a /etc/fstab >/dev/null
        fi
        sudo systemctl daemon-reload
        sudo mount -a || { warn "Mounting $NTFS_DRIVE failed — check /etc/fstab."; FAILURES+=("NTFS mount ($NTFS_DRIVE)"); }
    else
        warn "No UUID found on $NTFS_DRIVE — skipping the NTFS mount."
        FAILURES+=("NTFS mount ($NTFS_DRIVE)")
    fi
else
    echo "No NTFS drive specified, skipping..."
fi

### -------- GOOGLE CHROME + VS CODE --------
# The vendors' own repos, in rpm form (same sources ubuntu.sh uses as debs).
info "Installing Google Chrome and VS Code"
sudo tee /etc/yum.repos.d/google-chrome.repo >/dev/null <<'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
# Microsoft moved this repo from yumrepos/code to yumrepos/vscode (the old
# path 404s); their own config.repo ships gpgcheck=0, but the rpms are still
# signed with the regular Microsoft key, so keep the check on.
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf install -y google-chrome-stable || { warn "Google Chrome install failed."; FAILURES+=("Google Chrome"); }
sudo dnf install -y code || { warn "VS Code install failed."; FAILURES+=("VS Code"); }

### -------- DEVELOPMENT STACK (optional) --------
if [[ "$INSTALL_DEV" =~ ^[Nn] ]]; then
    info "Skipping the development stack"
else
    info "Installing the development stack"
    dnfi nodejs npm
    sudo dnf install -y java-25-openjdk-devel \
        || sudo dnf install -y java-latest-openjdk-devel \
        || sudo dnf install -y java-21-openjdk-devel \
        || { warn "No OpenJDK available."; FAILURES+=("OpenJDK"); }
    npm install -g @angular/cli --prefix="/home/$USERNAME/.local" \
        || { warn "Angular CLI install failed."; FAILURES+=("Angular CLI"); }
fi

### -------- GIT GLOBAL CONFIG (only when not already set) --------
git config --global user.name >/dev/null 2>&1 \
    || git config --global user.name "sandipsky"
git config --global user.email >/dev/null 2>&1 \
    || git config --global user.email "sandipshakya75@gmail.com"
git config --global core.pager >/dev/null 2>&1 \
    || git config --global core.pager cat

### -------- ZSH / STARSHIP --------
info "Setting up zsh"
dnfi zsh zsh-autosuggestions zsh-syntax-highlighting
# Repo package first; the official installer drops the same static binary
# into /usr/local/bin if the package isn't there.
if ! have starship; then
    sudo dnf install -y starship \
        || curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes --bin-dir /usr/local/bin \
        || warn "starship install failed — plain zsh prompt stays."
fi

# Same .zshrc as arch.sh writes, except the plugin sources probe both distros'
# paths (Fedora: /usr/share/<plugin>/, Arch: /usr/share/zsh/plugins/) and
# everything is guarded so a missing piece degrades silently.
if [[ ! -f "/home/$USERNAME/.zshrc" ]]; then
    cat > "/home/$USERNAME/.zshrc" <<'EOF'
for plugin in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -f $plugin ]] && source "$plugin"
done
unset plugin

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

setopt inc_append_history

PROMPT_EOL_MARK=''

command -v starship >/dev/null && eval "$(starship init zsh)"

export PATH="$PATH:$HOME/.local/bin"
EOF
else
    warn "~/.zshrc already exists — left as is."
fi

ZSH_BIN=$(command -v zsh || true)
if [[ -n "$ZSH_BIN" && "$(getent passwd "$USERNAME" | cut -d: -f7)" != "$ZSH_BIN" ]]; then
    sudo usermod -s "$ZSH_BIN" "$USERNAME"
fi

### -------- GAMING STACK (optional) --------
# Fedora's wine packaging pulls its own multilib set (no lib32-* lists like
# arch.sh); the .i686 GPU bits are what 32-bit Windows games need.
if [[ "$INSTALL_GAMING" =~ ^[Nn] ]]; then
    info "Skipping the gaming stack"
else
    info "Installing the gaming stack"
    dnfi wine winetricks lutris
    dnfi mesa-dri-drivers.i686 mesa-vulkan-drivers.i686
    if (( NVIDIA_OK )); then
        dnfi xorg-x11-drv-nvidia-libs.i686
    fi
fi

### -------- GNOME SHELL EXTENSIONS --------
# Dash to Dock comes from Fedora's package; "Disable Workspace Switcher
# Overlay" only exists on extensions.gnome.org, so it installs from the e.g.o
# API for the running Shell version. Both take effect at next login.
# gnome-extensions-app is the Extensions app (org.gnome.Extensions), for
# managing them from the desktop.
info "Installing GNOME Shell extensions"
dnfi gnome-shell-extension-dash-to-dock gnome-extensions-app

# Drop the stock system extensions (Apps Menu, Background Logo, Launch New
# Instance, Places Status Indicator, Window List). Removing apps-menu &
# friends also takes the GNOME Classic session with them — intended.
for pkg in gnome-shell-extension-apps-menu \
           gnome-shell-extension-background-logo \
           gnome-shell-extension-launch-new-instance \
           gnome-shell-extension-places-menu \
           gnome-shell-extension-window-list; do
    rpm -q "$pkg" >/dev/null 2>&1 && sudo dnf remove -y "$pkg" || true
done

# Download and install an extension from extensions.gnome.org by its numeric
# id (the /extension/<pk>/... part of its page URL). Prints the uuid.
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
    gnome-extensions install --force "$tmp/ext.zip" >&2 || return 1
    rm -rf "$tmp"
    echo "$uuid"
}

# Disable Workspace Switcher Overlay — https://extensions.gnome.org/extension/6358/
if EXT_UUID=$(install_ego_extension 6358); then
    as_session gnome-extensions enable "$EXT_UUID" \
        || warn "Installed but could not enable $EXT_UUID — enable it in the Extensions app."
else
    warn "Could not install 'Disable Workspace Switcher Overlay' (e.g.o #6358) — no build for this GNOME Shell?"
    FAILURES+=("GNOME extension: Disable Workspace Switcher Overlay")
fi

# (rpm -q, not `gnome-extensions info` — the latter asks the running Shell
# over D-Bus and would false-negative from a tty. `enable` only flips the
# gsettings key and checks the files on disk, so it works either way.)
if rpm -q gnome-shell-extension-dash-to-dock >/dev/null 2>&1; then
    as_session gnome-extensions enable dash-to-dock@micxgx.gmail.com \
        || warn "Dash to Dock installed but not enabled — enable it in the Extensions app."
else
    warn "Dash to Dock is not installed — Fedora package missing?"
    FAILURES+=("GNOME extension: Dash to Dock")
fi

### -------- BLUETOOTH --------
# Don't power the adapter on at boot; toggle it from quick settings when
# needed. (No rfkill-unblock unit here: GNOME manages rfkill itself, and
# airplane mode persisting across reboots is expected GNOME behavior.)
if [[ -f /etc/bluetooth/main.conf ]]; then
    if grep -q '^#*AutoEnable=' /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#*AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
    else
        printf '\n[Policy]\nAutoEnable=false\n' | sudo tee -a /etc/bluetooth/main.conf >/dev/null
    fi
fi

### -------- NAUTILUS SETTINGS --------
if have dbus-run-session || [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    as_session dconf load /org/gnome/nautilus/ < "$REPO_DIR/assets/nautilus"
else
    warn "No session bus and no dbus-run-session — skipped the Nautilus dconf import."
fi

### -------- REMOVE PREINSTALLED APPS --------
# Workstation apps this setup never uses. Audio/video/camera cover both the
# current GNOME core apps (Decibels/Showtime/Snapshot) and their older
# equivalents (Music/Totem/Cheese) — whichever this release shipped. The
# music role is filled by the vendored app built further down.
info "Removing preinstalled GNOME apps"
for pkg in gnome-contacts \
           yelp \
           gnome-boxes \
           decibels gnome-music \
           showtime totem \
           snapshot cheese \
           gnome-tour \
           gnome-weather \
           gnome-maps \
           simple-scan \
           gnome-connections; do
    rpm -q "$pkg" >/dev/null 2>&1 && sudo dnf remove -y "$pkg" || true
done

### -------- DESKTOP ENTRIES --------
APPS_DIR="/home/$USERNAME/.local/share/applications"
mkdir -p "$APPS_DIR"
cp "$REPO_DIR"/assets/apps/* "$APPS_DIR/"

files=(
    avahi-discover.desktop
    bssh.desktop
    bvnc.desktop
    qv4l2.desktop
    qvidcap.desktop
    cmake-gui.desktop
    lstopo.desktop
    winetricks.desktop
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

for file in "${files[@]}"; do
    src="/usr/share/applications/$file"
    dest="$APPS_DIR/$file"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        echo 'NoDisplay=true' >> "$dest"
    fi
done

# Entries that can't be listed by fixed name: Fedora splits wine's accessory
# apps (Notepad, Regedit, Wine Boot, …) into wine-*.desktop files, wine pulls
# in DOSBox Staging, and the OpenJDK entries embed the full version-release
# in their filenames. Same Actions-aware NoDisplay as the LibreOffice loop
# below, in case an entry ends with a [Desktop Action] section.
for src in /usr/share/applications/wine-*.desktop \
           /usr/share/applications/*dosbox*.desktop \
           /usr/share/applications/*openjdk*.desktop; do
    [[ -f "$src" ]] || continue
    dest="$APPS_DIR/$(basename "$src")"
    cp "$src" "$dest"
    if grep -q '^Actions=' "$dest"; then
        sed -i '/^Actions=/i NoDisplay=true' "$dest"
    else
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

# OBS Studio and qBittorrent (Qt apps) render too small — launch them at
# 125% scaling via local .desktop overrides.
for file in com.obsproject.Studio.desktop org.qbittorrent.qBittorrent.desktop; do
    src="/usr/share/applications/$file"
    dest="$APPS_DIR/$file"
    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        sed -i 's|^Exec=|Exec=env QT_SCALE_FACTOR=1.25 |' "$dest"
    fi
done

### -------- APP ICONS --------
ICON_DIR=/usr/share/icons/hicolor/scalable/apps
sudo mkdir -p "$ICON_DIR"
sudo cp "$REPO_DIR"/assets/icons/* "$ICON_DIR/"
# Papers is Evince's successor; reuse the same icon under its name.
sudo cp "$REPO_DIR/assets/icons/org.gnome.Evince.svg" "$ICON_DIR/org.gnome.Papers.svg"
# The stock terminal (Ptyxis on current Fedora) wears GNOME Terminal's icon
# (overwrites the package's own copy — a ptyxis update restores stock until
# the next run). gnome-console's name is covered too, for releases shipping
# that instead; a gnome-terminal default is already covered by the assets
# copy above (its icon IS org.gnome.Terminal.svg).
for icon in org.gnome.Ptyxis.svg org.gnome.Console.svg; do
    sudo cp "$REPO_DIR/assets/icons/org.gnome.Terminal.svg" "$ICON_DIR/$icon"
done
sudo gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

### -------- extract-audio --------
# Pulls audio out of videos as MP3 — Resolve on Linux can't decode AAC, so
# H.264 clips import silent without it.
sudo install -Dm755 "$REPO_DIR/assets/bin/extract-audio" /usr/local/bin/extract-audio
sudo restorecon -F /usr/local/bin/extract-audio 2>/dev/null || true

### -------- FONTS --------
# assets/fira is the interface font ('Fira Sans Book' — no repo supplies it);
# assets/fonts are the Microsoft faces documents need.
info "Installing fonts"
# The same font set arch.sh installs, in Fedora's package names (Fedora has
# no Fira Sans package — assets/fira below covers it; liberation-fonts is
# split into the three face packages here).
dnfi google-noto-sans-fonts google-noto-serif-fonts \
     google-noto-color-emoji-fonts google-noto-sans-cjk-fonts \
     liberation-sans-fonts liberation-serif-fonts liberation-mono-fonts \
     dejavu-fonts-all fontawesome4-fonts jetbrains-mono-fonts-all
sudo mkdir -p /usr/share/fonts/fira /usr/share/fonts/msfonts
sudo cp "$REPO_DIR"/assets/fira/*.ttf /usr/share/fonts/fira/
sudo cp "$REPO_DIR"/assets/fonts/* /usr/share/fonts/msfonts/
sudo restorecon -R /usr/share/fonts 2>/dev/null || true
sudo fc-cache -f

### -------- GDM GREETER FONT --------
# The login screen runs as the gdm user (DCONF_PROFILE=gdm), so the session
# gsettings below never reach it — give it Fira Sans via a system dconf db.
# The profile file is the canonical three lines from the GNOME/RHEL docs
# (Fedora ships no /etc/dconf/profile/gdm; this also guarantees system-db:gdm
# is actually in the profile).
info "Setting the GDM greeter font"
sudo mkdir -p /etc/dconf/profile /etc/dconf/db/gdm.d
sudo tee /etc/dconf/profile/gdm > /dev/null <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
sudo tee /etc/dconf/db/gdm.d/10-font > /dev/null <<'EOF'
[org/gnome/desktop/interface]
font-name='Fira Sans Book 12'
EOF
sudo restorecon -R /etc/dconf 2>/dev/null || true
# Best-effort: dconf update recompiles every /etc/dconf/db/*.d, so a broken
# keyfile in a db this script never wrote must not abort the rest of the run.
sudo dconf update || warn "dconf update failed — the greeter font applies after the next successful dconf update."

### -------- CONFIG --------
# Only the desktop-agnostic pieces of config/ — the rest (hypr, quickshell,
# noctalia, the systemd user units) is the Hyprland desktop's and stays out.
info "Installing configs"
if [[ -d "$REPO_DIR/config/vim" ]]; then
    cp -r "$REPO_DIR/config/vim" "/home/$USERNAME/.config/"
fi
cp "$REPO_DIR/assets/profile.png" "/home/$USERNAME/.face"

### -------- GSETTINGS / MIME DEFAULTS --------
as_session bash <<'EOF'
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.privacy remember-recent-files false
EOF

# xdg-mime refuses a .desktop it can't find, so don't let a missing app abort
# the rest of the run.
for mime in image/jpeg image/png image/webp; do
    xdg-mime default org.gnome.Loupe.desktop "$mime" || warn "Could not set Loupe as the default for $mime."
done
for mime in text/plain application/x-shellscript; do
    xdg-mime default org.gnome.TextEditor.desktop "$mime" || warn "Could not set Text Editor as the default for $mime."
done

### -------- MUSIC APP --------
# Its own install.sh is pacman-gated — install the Fedora equivalents of its
# dep list and drive meson directly, into the user's ~/.local.
build_music_app() {
    dnfi meson ninja-build gcc pkgconf-pkg-config gtk4-devel libadwaita-devel \
        gstreamer1-devel gstreamer1-plugins-base-devel gstreamer1-plugins-good \
        gstreamer1-plugins-bad-free gstreamer1-libav desktop-file-utils \
        hicolor-icon-theme || return 1

    local build
    build=$(mktemp -d) || return 1
    meson setup "$build" "$REPO_DIR/applications/music" --prefix="/home/$USERNAME/.local" || return 1
    meson compile -C "$build" || return 1
    meson install -C "$build" || return 1
    rm -rf "$build"

    update-desktop-database "/home/$USERNAME/.local/share/applications" 2>/dev/null || true
    gtk-update-icon-cache -q -t -f "/home/$USERNAME/.local/share/icons/hicolor" 2>/dev/null || true
}
info "Building the Music app from applications/music/"
if ! build_music_app; then
    warn "Music app build failed."
    FAILURES+=("Music app (applications/music)")
fi

### -------- SPOTIFY (+ adblock) --------
# Native client from negativo17's repo (the upstream binary, repackaged);
# spotify-adblock built from source with cargo — the equivalent of install.sh's
# AUR package. Best-effort: any failure just skips Spotify.
install_spotify() {
    if [[ ! -f /etc/yum.repos.d/fedora-spotify.repo ]]; then
        sudo dnf -y config-manager addrepo \
            --from-repofile=https://negativo17.org/repos/fedora-spotify.repo \
            || sudo dnf -y config-manager --add-repo=https://negativo17.org/repos/fedora-spotify.repo \
            || return 1
    fi
    sudo dnf install -y spotify-client || return 1

    dnfi cargo git make || return 1
    local build so
    build=$(mktemp -d) || return 1
    git clone --depth 1 https://github.com/abba23/spotify-adblock.git "$build/spotify-adblock" || return 1
    make -C "$build/spotify-adblock" || return 1
    so=$(find "$build/spotify-adblock/target/release" -maxdepth 1 -name 'lib*.so' | head -1)
    [[ -n "$so" ]] || return 1
    sudo install -Dm755 "$so" /usr/lib64/spotify-adblock.so || return 1
    sudo install -Dm644 "$build/spotify-adblock/config.toml" /etc/spotify-adblock/config.toml || return 1
    rm -rf "$build"

    # One user-level entry named plain "Spotify" that shadows the packaged one
    # (same filename, ~/.local wins), with the preload injected.
    if [[ -f /usr/share/applications/spotify.desktop ]]; then
        cp /usr/share/applications/spotify.desktop "$APPS_DIR/spotify.desktop"
        sed -i 's|^Exec=|Exec=env LD_PRELOAD=/usr/lib64/spotify-adblock.so |' "$APPS_DIR/spotify.desktop"
    fi
}
info "Installing Spotify with ad blocking"
if ! install_spotify; then
    warn "Spotify/spotify-adblock install failed — skipping, continuing to reboot."
    FAILURES+=("Spotify + spotify-adblock")
fi

# After every .desktop override is in place (including spotify's above).
update-desktop-database "$APPS_DIR"

### -------- DONE --------
info "INSTALLATION COMPLETE"
if (( ${#FAILURES[@]} )); then
    printf '\nThese parts did not complete:\n'
    printf '  - %s\n' "${FAILURES[@]}"
fi
cat <<EOF

Worth knowing:
  - The GNOME extensions (Dash to Dock, no workspace-switcher overlay) load
    at the login after the reboot.
  - zsh is the login shell from the reboot on (plugins + starship in ~/.zshrc).
  - GRUB is hidden and boot goes straight to Fedora. To boot Windows, use the
    firmware boot menu (Esc during power-on on ASUS).
  - The dGPU powers off when idle; right-click an app in GNOME for "Launch
    using Discrete Graphics Card". Check with: cat /sys/class/drm/card*/device/power_state
  - The battery stops charging at 80% (battery-charge-threshold.service).
EOF

echo
echo "Rebooting in 10 seconds — Ctrl-C to cancel."
sleep 10
sudo reboot
