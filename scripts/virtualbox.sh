#!/bin/bash
# virtualbox.sh — add or remove VirtualBox (the VM host, not guest additions)
# on the Arch desktops set up by install.sh / kde.sh.
#
#   ./scripts/virtualbox.sh install   VirtualBox + kernel modules (dkms) + guest-additions ISO
#   ./scripts/virtualbox.sh remove    undo everything install did, uninstall VirtualBox
#   ./scripts/virtualbox.sh status    show what is currently in place
#
# Run as your normal user; system steps use sudo. install.sh calls
# `install` when its VirtualBox prompt is answered yes — this is the same code.
#
# What `install` does:
#   1. pacman -S virtualbox virtualbox-host-dkms virtualbox-guest-iso plus the
#      <kernel>-headers package for every installed kernel. Arch dropped the
#      prebuilt virtualbox-host-modules-arch package, so dkms is the only way
#      to get the vboxdrv/vboxnetadp/vboxnetflt modules — the same mechanism
#      nvidia-open-dkms already relies on here, and pacman's dkms hook rebuilds
#      them on every kernel upgrade as long as the headers stay installed.
#      virtualbox-guest-iso puts VBoxGuestAdditions.iso where VirtualBox looks
#      for it, so "Insert Guest Additions CD image" works offline.
#   2. adds the user to the vboxusers group — needed for USB passthrough into
#      a VM (takes effect at the next login; install.sh reboots anyway)
#   3. loads the modules now, best-effort — the package's modules-load.d file
#      loads them at every boot, and a fresh install reboots right after this
#   4. hides the Qt developer tools that come along for the ride: virtualbox
#      depends on qt6-tools, which ships launcher entries for Qt Assistant,
#      Qt Widgets Designer, Qt Linguist and Qt D-Bus Viewer. They get
#      NoDisplay=true overrides in ~/.local/share/applications (copies of the
#      system files plus the key, each tagged with a marker comment). install.sh
#      writes the same overrides unconditionally — as stubs when qt6-tools
#      isn't installed yet — so on a fresh install this step only refreshes
#      them; it matters when VirtualBox is added later on a running system.
#
# `remove` refuses while a VM is running, unloads the modules, removes the
# packages (and the AUR extension pack if it was added by hand), and drops the
# vboxusers membership. It deliberately keeps dkms and the kernel headers
# (nvidia-open-dkms needs them), never touches the user's VMs
# (~/VirtualBox VMs) or settings (~/.config/VirtualBox), and leaves the
# Qt-tools overrides in place — those tools are hidden on this desktop no
# matter what pulls qt6-tools in, not only because of VirtualBox.
#
# Every step is idempotent — re-running either mode is harmless.

set -e

USERNAME=$(logname)
PACKAGES=(virtualbox virtualbox-host-dkms virtualbox-guest-iso)
MODULES=(vboxnetadp vboxnetflt vboxdrv)   # unload order; vboxdrv last (the others depend on it)
GROUP=vboxusers
# Launcher entries shipped by qt6-tools (a virtualbox dependency) that have no
# place in the app menu — hidden with NoDisplay=true overrides, same as
# install.sh does unconditionally (keep the two in sync).
QT_TOOLS_PKG=qt6-tools
QT_TOOLS_ENTRIES=(assistant.desktop designer.desktop linguist.desktop qdbusviewer.desktop)
SYSTEM_APPS=/usr/share/applications
APPS_DIR="$HOME/.local/share/applications"
# Written into every override so the scripts never touch a .desktop the user
# created themselves; install.sh tags its copies "dotfiles/install.sh".
MARKER='# hidden by dotfiles/scripts/virtualbox.sh'
MARKER_PREFIX='# hidden by dotfiles/'

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "run this as your normal user, not with sudo — the launcher overrides go into your home"

# An override in $APPS_DIR written by install.sh or this script: carries a
# dotfiles marker, or (older install.sh runs, which wrote no marker) differs
# from the system file only by NoDisplay=true. Anything else is the user's.
is_ours() {
    local f=$1 sys="$SYSTEM_APPS/$(basename "$1")"
    grep -qF "$MARKER_PREFIX" "$f" && return 0
    [[ -f "$sys" ]] || return 1
    diff -q <(grep -vxF 'NoDisplay=true' "$f") "$sys" >/dev/null
}

# Copy of the system entry plus NoDisplay=true — or, when qt6-tools isn't
# installed, a stub with the same Exec: GLib ignores an entry whose binary is
# missing, and once the package lands the stub takes over the id and hides it.
hide_qt_tools() {
    mkdir -p "$APPS_DIR"
    local name src dest
    for name in "${QT_TOOLS_ENTRIES[@]}"; do
        src="$SYSTEM_APPS/$name"
        dest="$APPS_DIR/$name"
        if [[ -f "$dest" ]] && ! is_ours "$dest"; then
            echo "kept:    $name (override not written by dotfiles)"
            continue
        fi
        if [[ -f "$src" ]]; then
            cp "$src" "$dest"
            echo "hidden:  $name"
        else
            cat > "$dest" <<EOF
[Desktop Entry]
Type=Application
Name=Qt ${name%.desktop}
Exec=${name%.desktop}6
Categories=Qt;Development;
EOF
            echo "hidden:  $name (stub — $QT_TOOLS_PKG not installed)"
        fi
        # Same shape as office.sh: the key must land in [Desktop Entry], so
        # insert it before Actions= when the file has one, else append.
        if grep -q '^Actions=' "$dest"; then
            sed -i -e "/^Actions=/i $MARKER" -e '/^Actions=/i NoDisplay=true' "$dest"
        else
            printf '%s\nNoDisplay=true\n' "$MARKER" >> "$dest"
        fi
    done
    command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
}

# pkgbase of every installed kernel (linux, linux-lts, linux-zen, ...) — read
# from the module trees so custom kernels are covered too, filtered against
# pacman so a leftover module dir from a removed kernel is ignored.
installed_kernels() {
    local f base
    for f in /usr/lib/modules/*/pkgbase; do
        [[ -f "$f" ]] || continue
        base=$(<"$f")
        pacman -Qq "$base" >/dev/null 2>&1 && echo "$base"
    done | sort -u
}

kernel_headers() {
    local k
    for k in $(installed_kernels); do
        if pacman -Si "$k-headers" >/dev/null 2>&1 || pacman -Qq "$k-headers" >/dev/null 2>&1; then
            echo "$k-headers"
        else
            echo "no $k-headers package for kernel $k — dkms can't build the modules for it" >&2
        fi
    done
}

do_install() {
    local virt
    if virt=$(systemd-detect-virt 2>/dev/null); then
        echo "note: this looks like a $virt guest — VirtualBox as a nested hypervisor only works with nested VT-x/AMD-V enabled on the outer VM" >&2
    fi

    local headers
    mapfile -t headers < <(kernel_headers)
    [[ ${#headers[@]} -gt 0 ]] || die "no installed kernel found under /usr/lib/modules"

    msg "Installing VirtualBox, the dkms host modules, the guest-additions ISO and ${headers[*]}"
    sudo pacman -S --noconfirm --needed "${PACKAGES[@]}" "${headers[@]}"

    msg "Adding $USERNAME to the $GROUP group (USB passthrough)"
    if id -nG "$USERNAME" | tr ' ' '\n' | grep -qx "$GROUP"; then
        echo "already a member"
    else
        sudo gpasswd -a "$USERNAME" "$GROUP"
        echo "takes effect at the next login"
    fi

    msg "Loading the kernel modules"
    # Fails when the running kernel isn't the one dkms just built for (e.g. a
    # kernel upgrade pending a reboot) — the modules-load.d file shipped by
    # virtualbox-host-dkms loads them at boot regardless.
    if sudo modprobe vboxdrv vboxnetadp vboxnetflt 2>/dev/null; then
        echo "loaded"
    else
        echo "could not load them for the running kernel — they load at the next boot"
    fi

    msg "Hiding the Qt developer tools that $QT_TOOLS_PKG adds to the launcher"
    hide_qt_tools

    msg "Done — launch VirtualBox from the app menu"
}

do_remove() {
    if pgrep -x VirtualBoxVM >/dev/null || pgrep -x VBoxHeadless >/dev/null; then
        die "a VM is running — shut it down first"
    fi

    msg "Unloading the kernel modules"
    local m
    for m in "${MODULES[@]}"; do
        if lsmod | grep -q "^$m "; then
            sudo modprobe -r "$m" || echo "could not unload $m — gone at the next boot" >&2
        fi
    done

    msg "Removing $USERNAME from the $GROUP group"
    if getent group "$GROUP" >/dev/null && id -nG "$USERNAME" | tr ' ' '\n' | grep -qx "$GROUP"; then
        sudo gpasswd -d "$USERNAME" "$GROUP"
    else
        echo "not a member"
    fi

    local installed=()
    for m in "${PACKAGES[@]}" virtualbox-ext-oracle; do
        pacman -Qq "$m" >/dev/null 2>&1 && installed+=("$m")
    done
    if [[ ${#installed[@]} -gt 0 ]]; then
        msg "Uninstalling ${installed[*]}"
        # -Rns (not -Rnsc): cascading would also pull out anything else that
        # happens to depend on a shared library; dkms and the headers stay.
        sudo pacman -Rns --noconfirm "${installed[@]}"
    else
        echo "VirtualBox is not installed"
    fi

    msg "Done — VMs in ~/VirtualBox VMs and ~/.config/VirtualBox were left alone"
}

do_status() {
    local p
    for p in "${PACKAGES[@]}"; do
        if pacman -Qq "$p" >/dev/null 2>&1; then
            echo "package:  $p $(pacman -Q "$p" | awk '{print $2}')"
        else
            echo "package:  $p not installed"
        fi
    done
    pacman -Qq virtualbox-ext-oracle >/dev/null 2>&1 \
        && echo "package:  virtualbox-ext-oracle $(pacman -Q virtualbox-ext-oracle | awk '{print $2}') (AUR extension pack)"
    local k
    for k in $(installed_kernels); do
        if pacman -Qq "$k-headers" >/dev/null 2>&1; then
            echo "headers:  $k-headers installed"
        else
            echo "headers:  $k-headers MISSING — dkms can't build for $k"
        fi
    done
    if command -v dkms >/dev/null; then
        local line
        line=$(dkms status 2>/dev/null | grep '^vboxhost' || true)
        echo "dkms:     ${line:-no vboxhost module registered}"
    else
        echo "dkms:     not installed"
    fi
    local m
    for m in vboxdrv vboxnetflt vboxnetadp; do
        if lsmod | grep -q "^$m "; then
            echo "module:   $m loaded"
        else
            echo "module:   $m not loaded"
        fi
    done
    if id -nG "$USERNAME" | tr ' ' '\n' | grep -qx "$GROUP"; then
        echo "group:    $USERNAME is in $GROUP"
    else
        echo "group:    $USERNAME is not in $GROUP"
    fi
    local name dest
    for name in "${QT_TOOLS_ENTRIES[@]}"; do
        dest="$APPS_DIR/$name"
        if [[ -f "$dest" ]] && is_ours "$dest"; then
            echo "hidden:   $name"
        elif [[ -f "$SYSTEM_APPS/$name" ]]; then
            echo "shown:    $name — no dotfiles override in $APPS_DIR"
        else
            echo "unhidden: $name — no override, $QT_TOOLS_PKG not installed (run install.sh, or this script's install, to seed it)"
        fi
    done
}

case "${1:-}" in
    install) do_install ;;
    remove)  do_remove ;;
    status)  do_status ;;
    *) echo "usage: $0 install|remove|status" >&2; exit 1 ;;
esac
