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
#   4. writes a virtualbox.desktop override into ~/.local/share/applications
#      that launches VirtualBox with QT_SCALE_FACTOR=1.25 — the same 125%
#      treatment install.sh gives OBS and qBittorrent, since Qt apps render
#      too small under Hyprland (every Exec= line gets the prefix, so the
#      "Open VM Manager" action is covered too). The override is tagged with a
#      marker comment so `remove` only ever deletes a file this script wrote.
#      The font (Fira Sans at Qt's 9pt) comes from config/fontconfig/fonts.conf
#      mapping sans-serif to Fira Sans — not from a Qt platform theme, which
#      VirtualBox ignores anyway (it forces xdgdesktopportal at startup).
#
# `remove` refuses while a VM is running, unloads the modules, removes the
# packages (and the AUR extension pack if it was added by hand), drops the
# vboxusers membership and deletes the .desktop override. It deliberately
# keeps dkms and the kernel headers (nvidia-open-dkms needs them) and never
# touches the user's VMs (~/VirtualBox VMs) or settings (~/.config/VirtualBox).
#
# Every step is idempotent — re-running either mode is harmless.

set -e

USERNAME=$(logname)
PACKAGES=(virtualbox virtualbox-host-dkms virtualbox-guest-iso)
MODULES=(vboxnetadp vboxnetflt vboxdrv)   # unload order; vboxdrv last (the others depend on it)
GROUP=vboxusers
APPS_DIR="/home/$USERNAME/.local/share/applications"
DESKTOP=virtualbox.desktop
SCALE=1.25
MARKER='# scaled by dotfiles/scripts/virtualbox.sh'

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

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

    msg "Launching VirtualBox at ${SCALE}x scaling ($APPS_DIR/$DESKTOP)"
    if [[ -f "/usr/share/applications/$DESKTOP" ]]; then
        mkdir -p "$APPS_DIR"
        # Rewritten on every install so a new upstream entry (changed Exec,
        # new actions) is picked up rather than pinned to an old copy.
        {
            echo "$MARKER"
            sed "s|^Exec=|Exec=env QT_SCALE_FACTOR=$SCALE |" "/usr/share/applications/$DESKTOP"
        } > "$APPS_DIR/$DESKTOP"
        command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
        echo "written"
    else
        echo "no /usr/share/applications/$DESKTOP — skipped" >&2
    fi

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

    msg "Removing the .desktop override"
    if [[ -f "$APPS_DIR/$DESKTOP" ]] && grep -qxF "$MARKER" "$APPS_DIR/$DESKTOP"; then
        rm -f "$APPS_DIR/$DESKTOP"
        command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
        echo "deleted"
    elif [[ -f "$APPS_DIR/$DESKTOP" ]]; then
        echo "$APPS_DIR/$DESKTOP was not written by this script — left alone"
    else
        echo "none"
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
    if [[ -f "$APPS_DIR/$DESKTOP" ]] && grep -qxF "$MARKER" "$APPS_DIR/$DESKTOP"; then
        echo "override: $DESKTOP at ${SCALE}x (QT_SCALE_FACTOR)"
    elif [[ -f "$APPS_DIR/$DESKTOP" ]]; then
        echo "override: $APPS_DIR/$DESKTOP exists but was not written by this script"
    else
        echo "override: none — VirtualBox launches at 1x"
    fi
}

case "${1:-}" in
    install) do_install ;;
    remove)  do_remove ;;
    status)  do_status ;;
    *) echo "usage: $0 install|remove|status" >&2; exit 1 ;;
esac
