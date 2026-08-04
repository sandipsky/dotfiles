#!/usr/bin/env bash
# Fedora counterpart of install.sh: turns a FRESH Fedora **minimal** install
# (network installer → "Minimal Install") into the same Hyprland + Noctalia
# desktop. Run it from the repo root as your normal user:
#
#   ./fedora-hyprland.sh
#
# Like install.sh it targets a fresh machine, never uninstalls prior setups,
# is destructive in places (overlays ~/.config, writes /etc units and udev
# rules, tunes /etc/dnf/dnf.conf, edits the login profile) and ends with a
# reboot.
#
# Requirements
# - Fedora 44 or newer. The vendored Nautilus fork is upstream 50.2.2, whose
#   deps (gtk4 >= 4.20, libadwaita >= 1.8, glycin-2, tinysparql >= 3.8) first
#   land in the GNOME 50 era. On an older Fedora the fork build is skipped and
#   stock Nautilus is left in place; everything else still installs.
# - Network. Fedora minimal ships no desktop stack at all, so this also pulls
#   in the pieces archinstall gave the Arch box (PipeWire, fonts, bluez,
#   portals, dconf) on top of install.sh's own package list.
#
# Where this deliberately differs from install.sh (Arch), and why:
# - Hyprland comes from the mineiro/hyprland COPR — Fedora retired its own
#   hyprland after F42, and the config is Lua-only so it needs Hyprland
#   >= 0.55 anyway. The script checks the available version up front and
#   aborts before touching anything if it is too old (COPRs go stale; the
#   previous standard one, solopasha/hyprland, died in 2025). The COPR also
#   carries hyprsunset, uwsm and the portal.
# - No makepkg/AUR. noctalia-qs (the pinned Quickshell fork) is built from the
#   vendored tarball with cmake and the Nautilus fork with meson, both into
#   /usr/local, which outranks /usr on PATH, XDG_DATA_DIRS and (after the
#   ld.so.conf.d drop-in below) the dynamic linker. Fedora's own `quickshell`
#   package is never installed — it is upstream 0.2+, not this fork.
# - The AC power udev rules tag the device for systemd instead of calling
#   runuser from RUN+=: udev's RUN commands execute in udev's own SELinux
#   domain, which cannot open a PAM session or reach the user bus. A system
#   oneshot unit does the handoff to the user manager instead.
# - The login profile is appended to, not overwritten: Fedora's ~/.bash_profile
#   puts ~/.local/bin on PATH and sources ~/.bashrc, which the desktop needs.
# - Nothing loosens or re-tightens sudoers — that step in install.sh undoes an
#   archinstall-only NOPASSWD line that Fedora never creates.
#
# Scope: wider than install.sh. On Arch the base/app layer lives in arch.sh;
# Fedora's base OS (partitioning, bootloader, the Windows dual-boot layout) is
# Anaconda's job during installation, so this script folds arch.sh's app and
# hardware layer in directly — tuned for this machine, an ASUS TUF F15
# (i5-10300H + GTX 1650 hybrid graphics): NVIDIA driver with runtime D3 power
# management, Chrome + VS Code, the dev stack, zsh as the login shell, the
# wine/lutris gaming stack, the 80% battery charge threshold, audio power
# save, Plymouth boot splash and a hidden GRUB menu with quiet/fast kernel
# args (boot Windows from the firmware boot menu — Esc on ASUS).
#
# Day-to-day helpers afterwards:
# - Noctalia UI changes:   ./reset.sh (its noctalia-qs *rebuild* branch is
#   Arch-only, but that branch is skipped when qs is already installed)
# - Nautilus fork changes: ./rebuild-nautilus-ubuntu.sh — the /usr/local
#   overlay it drives is exactly what this script sets up, so it works here.
set -e

USERNAME=$(logname)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=()

info() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# System-level steps below use sudo, but the script itself must run as the
# normal user — the two source builds compile in the user's own temp dirs and
# the Claude Code installer refuses to run as root.
if [[ $EUID -eq 0 ]]; then
    die "Run this as your normal user (./fedora-hyprland.sh), not with sudo — it asks for the password itself."
fi

. /etc/os-release
[[ "${ID:-}" == "fedora" ]] || die "This is the Fedora script — /etc/os-release says ID=${ID:-unknown}."
FEDORA_REL=$(rpm -E %fedora)

# Ask for the sudo password once, up front, and keep the credential cache
# fresh in the background — the dnf and compile steps outlast sudo's default
# timeout, and a mid-run re-prompt would stall the install.
sudo -v
( while kill -0 "$$" 2>/dev/null; do sleep 60; sudo -n -v; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

### -------- DNS --------
# Some routers hand out dead DNS servers via DHCP (the GLX router's first one,
# 110.44.112.200, never answers and glibc stalls 5 s per lookup on it). Prefer
# known-good resolvers globally — Domains=~. outranks any network's DHCP DNS —
# and cache via systemd-resolved, which also auto-skips unresponsive servers.
# Fedora already runs resolved; this only pins the servers.
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
# dnf downloads one package at a time, from whichever mirror it happened to
# pick — the slowest part of a fresh install, which pulls a couple of GB here.
# Inserted under the section header the same way install.sh adds pacman's
# IgnorePkg line. Values already present are left alone.
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

# dnf5-plugins provides `dnf copr` and `dnf builddep` (dnf-plugins-core on dnf4).
sudo dnf install -y dnf5-plugins || sudo dnf install -y dnf-plugins-core

# --skip-unavailable keeps one renamed/absent package from failing a whole
# transaction; critical packages are verified explicitly further down.
DNF_SKIP=--skip-unavailable
if ! dnf install --help 2>&1 | grep -q -- '--skip-unavailable'; then
    DNF_SKIP=--setopt=strict=0
fi
dnfi() { sudo dnf install -y "$DNF_SKIP" "$@"; }

# Fedora retired its own hyprland package after F42 (0.45.2), and the
# long-standing solopasha/hyprland COPR went stale in Oct 2025 at 0.51.1 —
# both far below what config/hypr/ needs. mineiro/hyprland is the maintained
# successor (checked 2026-08: hyprland 0.56.1 for F43/F44/rawhide, plus the
# rest of the stack this script uses from it: xdg-desktop-portal-hyprland,
# uwsm, hyprsunset, hyprpicker, hyprland-guiutils, cliphist). If it ever goes
# stale too, the version gate below aborts before anything is installed —
# find whichever COPR carries hyprland >= 0.55 that year and swap it in here.
info "Enabling mineiro/hyprland COPR"
sudo dnf -y copr enable mineiro/hyprland || warn "Could not enable the COPR — the version check below will say whether that matters."

# The Hyprland config in config/hypr/ is Lua-only (hyprlang .conf was removed
# upstream in 0.57), so a too-old Hyprland cannot read it at all. Check before
# installing anything else, while the system is still untouched.
HYPR_AVAIL=$(dnf repoquery --queryformat '%{version}\n' hyprland 2>/dev/null | sort -V | tail -1)
if [[ -z "$HYPR_AVAIL" ]]; then
    # dnf4 spells it --qf; fall back to parsing plain NEVRA output.
    HYPR_AVAIL=$(dnf repoquery --qf '%{version}\n' hyprland 2>/dev/null | sort -V | tail -1)
fi
if [[ -z "$HYPR_AVAIL" ]]; then
    HYPR_AVAIL=$(dnf repoquery hyprland 2>/dev/null | sed -nE 's/^hyprland-([0-9]+:)?([0-9][^-]*)-.*/\2/p' | sort -V | tail -1)
fi
if [[ -z "$HYPR_AVAIL" ]]; then
    warn "Could not query an available hyprland version — continuing anyway."
elif [[ "$(printf '%s\n' "0.55.0" "$HYPR_AVAIL" | sort -V | head -1)" != "0.55.0" ]]; then
    die "Newest available hyprland is $HYPR_AVAIL, but config/hypr/ is Lua-only and needs >= 0.55.
    Nothing has been installed yet. The mineiro/hyprland COPR has likely gone
    stale (as solopasha/hyprland did in 2025) — search COPR for whoever builds
    a current hyprland now, swap the 'dnf copr enable' line above to it, and
    re-run ./fedora-hyprland.sh."
fi
info "Hyprland $HYPR_AVAIL available"

# RPM Fusion, for the full ffmpeg build. Fedora's ffmpeg-free works for most
# things but assets/bin/extract-audio wants a dependable MP3 encoder, and
# Noctalia shells out to ffmpeg for video wallpapers/thumbnails.
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_REL.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_REL.noarch.rpm" \
        || warn "RPM Fusion setup failed — falling back to Fedora's ffmpeg-free."
fi

### -------- PACKAGES --------
# install.sh's pacman list, translated, plus the base desktop pieces a Fedora
# minimal install lacks (audio, fonts, bluez, portals, dconf, notifications).
info "Installing packages"
dnfi \
    hyprland \
    hyprland-guiutils \
    hyprpicker \
    hyprsunset \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    uwsm \
    wl-clipboard \
    cliphist \
    wtype \
    wlr-randr \
    grim \
    slurp \
    brightnessctl \
    luajit \
    polkit-gnome \
    libnotify \
    jq \
    alacritty \
    ImageMagick \
    python3 \
    python3-evdev \
    qt6-qtbase \
    qt6-qtdeclarative \
    qt6-qtwayland \
    qt6-qtsvg \
    qt6-qtmultimedia \
    qt6-qtimageformats \
    jemalloc \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    wireplumber \
    pulseaudio-utils \
    bluez \
    blueman \
    dconf \
    dbus-daemon \
    dbus-tools \
    gvfs \
    gvfs-mtp \
    ntfs-3g \
    ntfsprogs \
    xdg-user-dirs \
    xdg-user-dirs-gtk \
    xdg-utils \
    desktop-file-utils \
    gtk-update-icon-cache \
    fontconfig \
    gnome-themes-extra \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    gnome-calculator \
    gnome-text-editor \
    loupe \
    file-roller \
    obs-studio \
    qbittorrent \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    dejavu-sans-fonts \
    dejavu-sans-mono-fonts \
    google-noto-sans-fonts \
    google-noto-color-emoji-fonts \
    google-noto-emoji-color-fonts

# Papers is Evince's GNOME successor; take whichever this release carries.
# Deliberately without --skip-unavailable: skipping succeeds, and this needs a
# real failure for the fallback to fire.
sudo dnf install -y papers \
    || sudo dnf install -y evince \
    || warn "Neither papers nor evince is available — no PDF viewer installed."

# Full ffmpeg (RPM Fusion) replacing ffmpeg-free if it is already in.
sudo dnf install -y --allowerasing ffmpeg || dnfi ffmpeg-free

# power-profiles-daemon vs tuned-ppd: both own the same D-Bus name, and Fedora
# may have shipped tuned-ppd. The repo's acpoweron/acpoweroff units and
# Noctalia's battery widget both drive powerprofilesctl, so swap tuned out.
if rpm -q tuned-ppd >/dev/null 2>&1; then
    info "Swapping tuned-ppd for power-profiles-daemon"
    sudo dnf -y swap tuned-ppd power-profiles-daemon || sudo dnf install -y --allowerasing power-profiles-daemon
else
    dnfi power-profiles-daemon
fi

# Verify what the desktop cannot come up without. --skip-unavailable above
# means a renamed package is a warning, not a failed transaction, so check the
# commands themselves rather than trusting the package names.
MISSING=()
for cmd in hyprctl grim slurp wl-copy cliphist hyprsunset brightnessctl \
           powerprofilesctl nmcli bluetoothctl notify-send alacritty jq magick \
           gsettings dconf update-desktop-database fc-cache xdg-mime xdg-user-dirs-update; do
    have "$cmd" || MISSING+=("$cmd")
done
# Upstream names the binary Hyprland; some builds add a lowercase alias.
have Hyprland || have hyprland || MISSING+=("Hyprland")
if (( ${#MISSING[@]} )); then
    die "These commands are still missing after the package step: ${MISSING[*]}
    Nothing else has been configured yet. Find the Fedora $FEDORA_REL package that
    provides each (dnf provides '*/bin/<cmd>'), install it, then re-run ./fedora-hyprland.sh."
fi
for cmd in wtype wlr-randr uwsm ffmpeg dbus-run-session; do
    have "$cmd" || warn "$cmd is missing — the features using it will be degraded."
done

info "Enabling services"
sudo systemctl enable power-profiles-daemon.service
sudo systemctl enable bluetooth.service
# --global, because this runs from a bare tty where `systemctl --user` has no
# session bus to talk to yet.
sudo systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

### -------- CURSOR THEME --------
# environment.lua sets XCURSOR_THEME=BreezeX-Light. Fedora has no package for
# it (Arch pulls breezex-cursor-theme from the AUR), so take the upstream
# release tarball. Cosmetic, so a failure here is not fatal.
install_cursor_theme() {
    [[ -d /usr/share/icons/BreezeX-Light ]] && return 0
    local tmp url
    tmp=$(mktemp -d) || return 1
    url=$(curl -fsSL https://api.github.com/repos/ful1e5/BreezeX_Cursor/releases/latest \
        | jq -r '.assets[] | select(.name == "BreezeX-Light.tar.xz") | .browser_download_url') || return 1
    [[ -n "$url" && "$url" != "null" ]] || return 1
    curl -fsSL "$url" -o "$tmp/BreezeX-Light.tar.xz" || return 1
    sudo tar -xJf "$tmp/BreezeX-Light.tar.xz" -C /usr/share/icons || return 1
    rm -rf "$tmp"
}
info "Installing the BreezeX-Light cursor theme"
install_cursor_theme || { warn "BreezeX-Light install failed — cursors fall back to Adwaita."; FAILURES+=("BreezeX-Light cursor theme"); }

### -------- CLAUDE CODE --------
info "Installing Claude Code"
curl -fsSL https://claude.ai/install.sh | bash || { warn "Claude Code install failed."; FAILURES+=("Claude Code"); }

### -------- NVIDIA (GTX 1650 + i5-10300H hybrid graphics) --------
# RPM Fusion's akmod-nvidia rebuilds the kernel module automatically on every
# kernel update (arch.sh's dkms equivalent). The TUF F15's panel is wired to
# the Intel iGPU — Hyprland renders on i915 and the dGPU is offload-only — so
# none of arch.sh's early-KMS/initramfs work for nvidia applies here. What
# does carry over unchanged: the runtime-PM modprobe options and udev rules,
# which let the card power off completely (D3cold) while nothing uses it —
# the single biggest battery win on this machine.
NVIDIA_OK=0
install_nvidia() {
    rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 || return 1
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda || return 1
    # -power ships the nvidia-suspend/resume units; libva-nvidia-driver adds
    # VA-API on the dGPU; switcheroo-control gives Lutris/Steam their
    # "launch on discrete GPU" option (and `switcherooctl launch <app>`).
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
info "Installing the NVIDIA driver (RPM Fusion akmod)"
if install_nvidia; then
    NVIDIA_OK=1
else
    warn "NVIDIA driver install failed — the desktop still runs fine on the Intel iGPU."
    FAILURES+=("NVIDIA driver (akmod-nvidia)")
fi

### -------- POWER / PERFORMANCE --------
# arch.sh's laptop tuning, ported: audio codec suspend (also a precondition
# for the dGPU reaching D3cold — the HDA function must idle), the 80% battery
# charge threshold, zram sized like the Arch box, periodic TRIM, and VA-API
# on the iGPU so video decode doesn't burn CPU. Day-to-day performance/
# power-saver switching is already handled by power-profiles-daemon + the AC
# udev rules further down.
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

### -------- BOOT (Plymouth splash + hidden GRUB + kernel args) --------
# Fedora minimal boots verbose to a text console and shows the GRUB menu.
# This gives it Workstation's boot instead: Plymouth's bgrt theme (firmware
# logo + spinner, falling back to the Fedora-logo spinner when the firmware
# provides no BGRT image), a hidden GRUB menu, and arch.sh's quiet/fast
# kernel args. Windows stays untouched on its own partitions — boot it from
# the firmware boot menu (Esc on ASUS); os-prober stays off so it never
# reappears in (and slows down) grub2-mkconfig.
info "Setting up boot splash and hiding GRUB"
dnfi plymouth plymouth-system-theme fedora-logos

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

if [[ "$(sudo plymouth-set-default-theme 2>/dev/null)" != "bgrt" ]]; then
    sudo plymouth-set-default-theme bgrt || warn "Could not set the Plymouth theme."
fi
# Rebuild every initramfs so plymouth + theme are inside (also covers a kernel
# newer than the running one from the upgrade at the top). Takes a minute.
# dracut writes to a temp file and moves it, so a failure keeps the old one.
sudo dracut -f --regenerate-all \
    || { warn "initramfs rebuild failed — boot stays verbose (no splash)."; FAILURES+=("Plymouth initramfs rebuild"); }

# Biggest boot-time win: don't block boot waiting for the network.
sudo systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service 2>/dev/null || true

### -------- GOOGLE CHROME + VS CODE --------
# The vendors' own repos, in rpm form (same sources ubuntu.sh uses as debs).
# Chrome is what keybinds.lua's Super+W launches (google-chrome-stable).
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
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/code
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf install -y google-chrome-stable || { warn "Google Chrome install failed."; FAILURES+=("Google Chrome"); }
sudo dnf install -y code || { warn "VS Code install failed."; FAILURES+=("VS Code"); }

### -------- DEVELOPMENT STACK --------
# arch.sh's dev half: node + npm, a current JDK (newest available, mirroring
# arch.sh's jdk25), the Angular CLI into ~/.local, and the git identity.
info "Installing the development stack"
dnfi git nodejs npm
sudo dnf install -y java-25-openjdk-devel \
    || sudo dnf install -y java-latest-openjdk-devel \
    || sudo dnf install -y java-21-openjdk-devel \
    || { warn "No OpenJDK available."; FAILURES+=("OpenJDK"); }
npm install -g @angular/cli --prefix="/home/$USERNAME/.local" \
    || { warn "Angular CLI install failed."; FAILURES+=("Angular CLI"); }

git config --global user.name "sandipsky"
git config --global user.email "sandipshakya75@gmail.com"
git config --global core.pager cat

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

# Default shell. Must happen BEFORE the AUTOLOGIN section below, which reads
# the login shell to decide whether the Hyprland autostart goes to ~/.zprofile
# or ~/.bash_profile.
ZSH_BIN=$(command -v zsh || true)
if [[ -n "$ZSH_BIN" && "$(getent passwd "$USERNAME" | cut -d: -f7)" != "$ZSH_BIN" ]]; then
    sudo usermod -s "$ZSH_BIN" "$USERNAME"
fi

### -------- GAMING STACK --------
# arch.sh's list is mostly lib32-* runtime deps that Arch makes you spell out
# by hand; Fedora's wine packaging pulls its own multilib set, so the list
# collapses to the actual programs (Super+G launches lutris). The .i686 GPU
# bits are what 32-bit Windows games need to reach the drivers.
info "Installing the gaming stack"
dnfi wine winetricks lutris
dnfi mesa-dri-drivers.i686 mesa-vulkan-drivers.i686
if (( NVIDIA_OK )); then
    dnfi xorg-x11-drv-nvidia-libs.i686
fi

### -------- NOCTALIA-QS (Quickshell fork) --------
# Built only from the vendored tarball in applications/noctalia-qs/ — upstream
# discontinued the fork (Noctalia v5 dropped Quickshell) and 0.0.12 is final,
# so there is nothing to track and Fedora's own `quickshell` package (0.2+) is
# a different thing entirely. Installed to /usr/local; joystick-wake calls
# /usr/bin/qs by absolute path, so that gets a symlink.
build_noctalia_qs() {
    dnfi \
        cmake ninja-build gcc gcc-c++ make pkgconf-pkg-config git \
        qt6-qtbase-devel qt6-qtbase-private-devel \
        qt6-qtdeclarative-devel qt6-qtdeclarative-private-devel \
        qt6-qtwayland-devel qt6-qtwayland-private-devel \
        qt6-qtshadertools-devel qt6-qtsvg-devel \
        cli11-devel jemalloc-devel libdrm-devel mesa-libgbm-devel \
        wayland-devel wayland-protocols-devel libxcb-devel \
        pam-devel polkit-devel glib2-devel pipewire-devel \
        spirv-tools vulkan-headers || return 1

    local build src
    build=$(mktemp -d) || return 1
    tar -xzf "$REPO_DIR/applications/noctalia-qs/noctalia-qs-0.0.12.tar.gz" -C "$build" || return 1
    src="$build/noctalia-qs-0.0.12"

    # Mirrors applications/noctalia-qs/PKGBUILD's cmake flags, with Fedora's
    # libdir and CRASH_HANDLER (the actual option name; the PKGBUILD's
    # CRASH_REPORTER is a no-op) left off — it needs cpptrace.
    cmake -G Ninja -B "$src/build" -S "$src" -Wno-dev \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D INSTALL_QML_PREFIX=lib64/qt6/qml \
        -D DISTRIBUTOR="dotfiles fedora-hyprland.sh" \
        -D CRASH_HANDLER=OFF \
        -D USE_JEMALLOC=ON || return 1
    cmake --build "$src/build" || return 1
    sudo cmake --install "$src/build" || return 1
    rm -rf "$build"

    # Fedora's linker does not search /usr/local by default (Debian's does,
    # which is why ubuntu.sh gets away without this) — and the Nautilus
    # overlay below puts libnautilus-extension there too.
    sudo tee /etc/ld.so.conf.d/zz-usrlocal.conf >/dev/null <<'EOF'
/usr/local/lib
/usr/local/lib64
EOF
    sudo ldconfig
    sudo ln -sf /usr/local/bin/qs /usr/bin/qs
    sudo restorecon -R /usr/local/bin /usr/local/lib64 2>/dev/null || true
    have qs || return 1
}
info "Building noctalia-qs (Quickshell fork) from applications/noctalia-qs/"
if ! build_noctalia_qs; then
    warn "noctalia-qs build failed — Noctalia (bar, launcher, lock screen, notifications) will not run."
    FAILURES+=("noctalia-qs (Quickshell fork) — the shell will not start without it")
fi

### -------- NAUTILUS FORK --------
# No makepkg on Fedora, so the vendored tree (upstream 50.2.2 + local patches,
# see docs/nautilus-patches.md) is built with meson into /usr/local, which
# shadows the stock nautilus package: PATH, XDG_DATA_DIRS (.desktop file,
# GSettings schema, D-Bus activation) and the linker all prefer it. Stock
# nautilus stays installed for its runtime deps (gvfs, localsearch, glycin)
# but its binary is never the one that runs — the same arrangement ubuntu.sh
# uses, so ./rebuild-nautilus-ubuntu.sh is the iteration helper here too.
build_nautilus_fork() {
    dnfi nautilus meson ninja-build gcc blueprint-compiler appstream \
        desktop-file-utils gettext glib2-devel gobject-introspection-devel \
        libselinux-devel || return 1
    sudo dnf builddep -y nautilus \
        || sudo dnf builddep -y --enablerepo='*-source' nautilus \
        || dnfi gtk4-devel libadwaita-devel gnome-desktop4-devel gnome-autoar-devel \
                libportal-gtk4-devel tinysparql-devel libglycin-devel libglycin-gtk4-devel \
                libcloudproviders-devel gexiv2-devel gdk-pixbuf2-devel \
                gstreamer1-plugins-base-devel libicu-devel \
        || return 1

    local build
    build=$(mktemp -d) || return 1
    meson setup "$build" "$REPO_DIR/applications/nautilus-fork/nautilus" \
        --prefix=/usr/local \
        --libdir=lib64 \
        -D docs=false \
        -D tests=none \
        -D selinux=enabled || return 1
    meson compile -C "$build" || return 1
    sudo meson install -C "$build" || return 1
    rm -rf "$build"

    sudo ldconfig
    sudo glib-compile-schemas /usr/local/share/glib-2.0/schemas 2>/dev/null || true
    sudo update-desktop-database /usr/local/share/applications 2>/dev/null || true
    sudo restorecon -R /usr/local 2>/dev/null || true
    [[ -x /usr/local/bin/nautilus ]] || return 1
}
if (( FEDORA_REL < 44 )); then
    warn "Fedora $FEDORA_REL is older than 44 — skipping the Nautilus fork (its GNOME 50 deps are not in this release). Stock Nautilus stays as the file manager."
    FAILURES+=("Nautilus fork skipped (needs Fedora 44+); stock Nautilus installed instead")
    dnfi nautilus
else
    info "Building the Nautilus fork from applications/nautilus-fork/"
    if ! build_nautilus_fork; then
        warn "Nautilus fork build failed — stock Nautilus (no patched context menus) stays in place."
        FAILURES+=("Nautilus fork build")
    fi
fi

### -------- AC POWER SWITCHING --------
# assets/99-power.rules calls runuser straight out of udev's RUN+=. That works
# on Arch but not under SELinux: RUN commands inherit udev's own domain, which
# cannot open a PAM session or reach the user bus. Tag the device instead and
# let systemd start a system oneshot that does the handoff.
info "Installing the AC power udev rules"
sudo tee /etc/udev/rules.d/99-power.rules >/dev/null <<'EOF'
# /etc/udev/rules.d/99-power.rules
# Fedora variant of assets/99-power.rules — see fedora-hyprland.sh for why the handoff
# goes through a systemd unit instead of RUN+="runuser ...".

# AC connected
SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ac-power-on.service"

# AC disconnected
SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ac-power-off.service"
EOF

RUNUSER=$(command -v runuser || echo /usr/sbin/runuser)
for event in on off; do
    case "$event" in
        on)  desc="AC connected";    unit=acpoweron.service ;;
        off) desc="AC disconnected"; unit=acpoweroff.service ;;
    esac
    sudo tee "/etc/systemd/system/ac-power-$event.service" >/dev/null <<EOF
[Unit]
Description=Hand the $desc event to $USERNAME's user session

[Service]
Type=oneshot
ExecStart=$RUNUSER -l $USERNAME -c 'systemctl --user start $unit'
EOF
done
sudo restorecon -F /etc/udev/rules.d/99-power.rules /etc/systemd/system/ac-power-*.service 2>/dev/null || true
sudo udevadm control --reload
sudo systemctl daemon-reload

### -------- BLUETOOTH --------
if [[ -f /etc/bluetooth/main.conf ]]; then
    if grep -q '^#*AutoEnable=' /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#*AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
    else
        printf '\n[Policy]\nAutoEnable=false\n' | sudo tee -a /etc/bluetooth/main.conf >/dev/null
    fi
fi

# systemd-rfkill persists rfkill soft blocks across reboots (e.g. one left by
# Noctalia's airplane mode), and BlueZ can't power a blocked adapter — the bar
# widget's Bluetooth toggle would silently fail forever. Clear the block every
# boot; the adapter still stays off until toggled (AutoEnable=false above).
RFKILL=$(command -v rfkill || echo /usr/sbin/rfkill)
sudo tee /etc/systemd/system/bluetooth-rfkill-unblock.service >/dev/null <<EOF
[Unit]
Description=Clear persisted Bluetooth rfkill soft block
After=systemd-rfkill.service

[Service]
Type=oneshot
ExecStart=$RFKILL unblock bluetooth

[Install]
WantedBy=multi-user.target
EOF
sudo restorecon -F /etc/systemd/system/bluetooth-rfkill-unblock.service 2>/dev/null || true
sudo systemctl enable bluetooth-rfkill-unblock.service

### -------- POLKIT AGENT PATH --------
# autostart.lua launches /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
# (the Arch path). Fedora ships the same binary in /usr/libexec — symlink it so
# the shared config keeps working on both distros.
if [[ -x /usr/libexec/polkit-gnome-authentication-agent-1 && ! -e /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
    sudo mkdir -p /usr/lib/polkit-gnome
    sudo ln -sf /usr/libexec/polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
elif [[ ! -x /usr/libexec/polkit-gnome-authentication-agent-1 && ! -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
    warn "polkit-gnome not found — GUI privilege prompts (Nautilus admin://, etc.) will not appear."
fi

### -------- NAUTILUS SETTINGS --------
if have dbus-run-session; then
    dbus-run-session -- dconf load /org/gnome/nautilus/ < "$REPO_DIR/assets/nautilus"
else
    warn "dbus-run-session missing — skipped the Nautilus dconf import."
fi

### -------- DESKTOP ENTRIES --------
APPS_DIR="/home/$USERNAME/.local/share/applications"
mkdir -p "$APPS_DIR"
cp "$REPO_DIR"/assets/apps/* "$APPS_DIR/"

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
# The Nautilus fork installs its own icon under /usr/local/share, which comes
# first in XDG_DATA_DIRS and would otherwise shadow the custom one.
if [[ -d /usr/local/share/icons/hicolor/scalable/apps ]]; then
    sudo cp "$REPO_DIR/assets/icons/org.gnome.Nautilus.svg" \
        /usr/local/share/icons/hicolor/scalable/apps/
fi
sudo gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
sudo gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor 2>/dev/null || true

### -------- extract-audio --------
# Pulls audio out of videos as MP3 (Resolve on Linux can't decode AAC, so
# H.264 clips import silent without it). /usr/local/bin so it works from any
# shell/directory.
sudo install -Dm755 "$REPO_DIR/assets/bin/extract-audio" /usr/local/bin/extract-audio
sudo restorecon -F /usr/local/bin/extract-audio 2>/dev/null || true

### -------- FONTS --------
# Fedora convention is one directory per family. assets/fira carries the
# interface font the config asks for ('Fira Sans Book'), which nothing in the
# repos would supply; assets/fonts are the Microsoft faces documents need.
info "Installing fonts"
sudo mkdir -p /usr/share/fonts/fira /usr/share/fonts/msfonts
sudo cp "$REPO_DIR"/assets/fira/*.ttf /usr/share/fonts/fira/
sudo cp "$REPO_DIR"/assets/fonts/* /usr/share/fonts/msfonts/
sudo restorecon -R /usr/share/fonts 2>/dev/null || true
sudo fc-cache -f

### -------- CONFIG --------
info "Installing config/ into ~/.config"
mkdir -p "/home/$USERNAME/.config"
cp -r "$REPO_DIR"/config/* "/home/$USERNAME/.config/"
sed -i "s|USERNAME|$USERNAME|g" "/home/$USERNAME/.config/noctalia/settings.json"
cp "$REPO_DIR/assets/profile.png" "/home/$USERNAME/.face"
# settings.json points wallpaper handling here; Noctalia generates its colour
# scheme from whatever lands in this directory.
mkdir -p "/home/$USERNAME/Pictures/Wallpapers"

# joystick-wake: gamepad input keeps the screen awake (Noctalia's idle service
# only counts mouse/keyboard). Enabled via the static wants symlink because the
# install runs from a bare tty where `systemctl --user` has no session bus.
install -Dm755 "$REPO_DIR/assets/bin/joystick-wake" "/home/$USERNAME/.local/bin/joystick-wake"
mkdir -p "/home/$USERNAME/.config/systemd/user/graphical-session.target.wants"
ln -sf ../joystick-wake.service \
    "/home/$USERNAME/.config/systemd/user/graphical-session.target.wants/joystick-wake.service"

### -------- AUTOLOGIN --------
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
# Fedora 42+ merged /usr/sbin into /usr/bin, older releases did not — take
# whichever path this install actually has.
AGETTY=$(command -v agetty || echo /usr/sbin/agetty)
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-$AGETTY --autologin $USERNAME --skip-login --nonewline --noissue --noclear %I \$TERM
Type=idle
EOF
sudo restorecon -F /etc/systemd/system/getty@tty1.service.d/override.conf 2>/dev/null || true

LOGIN_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
if [[ "$(basename "$LOGIN_SHELL")" == "zsh" ]]; then
    AUTOSTART_PROFILE="/home/$USERNAME/.zprofile"
else
    AUTOSTART_PROFILE="/home/$USERNAME/.bash_profile"
    # Fedora's skel profile is what puts ~/.local/bin (claude, music) on PATH
    # and sources ~/.bashrc — seed it rather than starting from an empty file.
    if [[ ! -f "$AUTOSTART_PROFILE" && -f /etc/skel/.bash_profile ]]; then
        cp /etc/skel/.bash_profile "$AUTOSTART_PROFILE"
    fi
fi

# Appended, not overwritten (install.sh can overwrite because archinstall's
# profile holds nothing worth keeping). The marker keeps re-runs idempotent.
AUTOSTART_MARKER='# >>> hyprland autostart (dotfiles) >>>'
if ! grep -qF "$AUTOSTART_MARKER" "$AUTOSTART_PROFILE" 2>/dev/null; then
    cat >> "$AUTOSTART_PROFILE" <<EOF

$AUTOSTART_MARKER
# Before uwsm captures the environment: zsh logins don't get ~/.local/bin on
# PATH from Fedora's /etc/profile skel the way bash does, and the session (so
# the launcher's .desktop entries: claude, music, ng) inherits PATH from here.
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$PATH:\$HOME/.local/bin" ;; esac
if [[ -z "\$WAYLAND_DISPLAY" && "\$(tty)" == "/dev/tty1" ]]; then
    if command -v uwsm >/dev/null 2>&1 && uwsm check may-start; then
        exec uwsm start hyprland.desktop >/dev/null 2>&1
    elif command -v Hyprland >/dev/null 2>&1; then
        # Fallback only: without uwsm nothing reaches graphical-session.target,
        # so the joystick-wake user unit stays inactive.
        exec Hyprland >/dev/null 2>&1
    fi
fi
# <<< hyprland autostart (dotfiles) <<<
EOF
fi

### -------- GSETTINGS / MIME DEFAULTS --------
if have dbus-run-session; then
    dbus-run-session -- bash <<'EOF'
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface font-name 'Fira Sans Book 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-Light'
gsettings set org.gnome.desktop.privacy remember-recent-files false
EOF
else
    warn "dbus-run-session missing — skipped the GTK theme/font gsettings."
fi

# xdg-mime refuses a .desktop it can't find, so don't let a missing app abort
# the rest of the run.
for mime in image/jpeg image/png image/webp; do
    xdg-mime default org.gnome.Loupe.desktop "$mime" || warn "Could not set Loupe as the default for $mime."
done
for mime in text/plain application/x-shellscript; do
    xdg-mime default org.gnome.TextEditor.desktop "$mime" || warn "Could not set Text Editor as the default for $mime."
done

xdg-user-dirs-update

### -------- MUSIC APP --------
# applications/music/install.sh is pacman-gated, so install the Fedora
# equivalents of its dep list and drive meson directly, exactly as that
# script's own fallback instructions describe. Installs to the user's ~/.local.
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
# Fedora has no AUR. The native client comes from negativo17's Spotify repo
# (the same upstream binary, repackaged) and spotify-adblock is built from
# source with cargo — together the equivalent of install.sh's spotify-adblock
# AUR package. Best-effort: any failure just skips Spotify.
# Note fix-spotify.sh mentions /usr/lib/spotify-adblock.so; on Fedora the
# library lands in /usr/lib64.
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
    # (same filename, ~/.local wins), with the preload injected — instead of
    # Arch's hide-one/rename-the-other pair.
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

Rebooting into tty1 autologin, which execs uwsm start hyprland.desktop.

Worth knowing:
  - zsh is the login shell from this reboot on (plugins + starship in ~/.zshrc).
  - GRUB is hidden and boot is silent behind the Plymouth splash. To boot
    Windows, use the firmware boot menu (Esc during power-on on ASUS).
  - The dGPU powers off when idle; run games on it via Lutris's discrete-GPU
    option or: switcherooctl launch <app>. Check with: cat /sys/class/drm/card*/device/power_state
  - The battery stops charging at 80% (battery-charge-threshold.service).
  - ~/Pictures/Wallpapers is empty, so Noctalia has nothing to generate its
    colour scheme from until you drop wallpapers in.
  - Noctalia UI changes: ./reset.sh — Nautilus fork changes: ./rebuild-nautilus-ubuntu.sh
EOF

echo
echo "Rebooting in 10 seconds — Ctrl-C to cancel."
sleep 10
sudo reboot
