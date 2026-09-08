#!/bin/bash
# plymouth.sh — add or remove the Plymouth boot splash on a system installed
# by arch.sh + install.sh (systemd-boot, systemd mkinitcpio hook, early KMS).
#
#   ./scripts/plymouth.sh install   boot splash, default theme minus the Arch logo
#   ./scripts/plymouth.sh remove    undo everything install did, uninstall plymouth
#   ./scripts/plymouth.sh status    show what is currently in place
#
# Run as your normal user; system steps use sudo. install.sh calls
# `install` when its Plymouth prompt is answered yes — this is the same code.
#
# What `install` does:
#   1. pacman -S plymouth
#   2. puts the `plymouth` hook right after `systemd` in /etc/mkinitcpio.conf
#      (after `udev` on a busybox initramfs)
#   3. appends `splash` to the options line of every systemd-boot entry
#   4. clones the default theme (bgrt on Arch — spinner under the firmware's
#      OEM logo; plain spinner without BGRT) to <theme>-nologo WITHOUT
#      watermark.png, the distro logo drawn below the spinner, and makes the
#      clone the default. Cloning instead of deleting the file from the
#      package's own theme means a plymouth upgrade can't bring the logo back.
#      bgrt has no images of its own (its ImageDir points at spinner), so the
#      clone is built from whatever ImageDir the theme uses.
#   5. rebuilds the initramfs (plymouth-set-default-theme -R)
#   6. masks the poweroff/reboot/halt/kexec units so the splash shows at boot
#      only — shutdown goes straight to the quiet, cursor-less console
#
# `remove` reverses those in the safe order: hook and `splash` out first,
# units unmasked, the -nologo clone deleted, the package removed (-Rns also
# drops /etc/plymouth/plymouthd.conf), then mkinitcpio -P so the initramfs
# no longer references a hook that isn't installed.
#
# Every step is idempotent — re-running either mode is harmless.

set -e

MKINITCPIO=/etc/mkinitcpio.conf
ENTRIES=/boot/loader/entries
THEMES=/usr/share/plymouth/themes
UNITS=(plymouth-poweroff.service plymouth-reboot.service plymouth-halt.service plymouth-kexec.service)

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# The theme install cloned (or would clone): the current default, with a
# -nologo suffix stripped so a re-run doesn't clone the clone.
base_theme() {
    local theme
    theme=$(plymouth-set-default-theme 2>/dev/null || true)
    theme=${theme%-nologo}
    echo "${theme:-spinner}"
}

do_install() {
    msg "Installing plymouth"
    sudo pacman -S --noconfirm --needed plymouth

    msg "Adding the plymouth mkinitcpio hook"
    if grep -Eq '^HOOKS=.*\bplymouth\b' "$MKINITCPIO"; then
        echo "hook already present"
    elif grep -Eq '^HOOKS=.*\bsystemd\b' "$MKINITCPIO"; then
        sudo sed -i -E '/^HOOKS=/s/\bsystemd\b/systemd plymouth/' "$MKINITCPIO"
    elif grep -Eq '^HOOKS=.*\budev\b' "$MKINITCPIO"; then
        sudo sed -i -E '/^HOOKS=/s/\budev\b/udev plymouth/' "$MKINITCPIO"
    else
        die "no systemd or udev hook in $MKINITCPIO HOOKS= — add plymouth by hand"
    fi

    msg "Adding 'splash' to the systemd-boot entries"
    local entry found=0
    for entry in "$ENTRIES"/*.conf; do
        [[ -f "$entry" ]] || continue
        found=1
        if grep -Eq '^options .*\bsplash\b' "$entry"; then
            echo "$entry: already has splash"
        else
            sudo sed -i -E '/^options /s/$/ splash/' "$entry"
            echo "$entry: added"
        fi
    done
    [[ $found -eq 1 ]] || echo "no entries in $ENTRIES — add 'splash' to your kernel command line by hand" >&2

    local theme src_dir src_conf image_dir dst
    theme=$(base_theme)
    src_dir="$THEMES/$theme"
    src_conf="$src_dir/$theme.plymouth"
    [[ -f "$src_conf" ]] || die "theme '$theme' not found at $src_conf"
    image_dir=$(sed -nE 's/^ImageDir=//p' "$src_conf" | head -n1)
    image_dir=${image_dir:-$src_dir}
    dst="$THEMES/$theme-nologo"

    msg "Building theme $theme-nologo ($theme without watermark.png)"
    sudo rm -rf "$dst"
    sudo mkdir -p "$dst"
    sudo cp -r "$image_dir"/. "$dst/"
    sudo rm -f "$dst"/*.plymouth "$dst/watermark.png"
    sudo sed -E \
        -e 's/^(Name=.*)/\1 (no logo)/' \
        -e "s|^ImageDir=.*|ImageDir=$dst|" \
        -e "s|^ScriptFile=$src_dir/|ScriptFile=$dst/|" \
        "$src_conf" | sudo tee "$dst/$theme-nologo.plymouth" >/dev/null
    if ! grep -q '^ImageDir=' "$dst/$theme-nologo.plymouth"; then
        sudo sed -i "/^\[two-step\]/a ImageDir=$dst" "$dst/$theme-nologo.plymouth"
    fi

    msg "Setting $theme-nologo as default and rebuilding the initramfs"
    sudo plymouth-set-default-theme -R "$theme-nologo"

    msg "Disabling the shutdown splash"
    sudo systemctl mask "${UNITS[@]}"

    msg "Done — the splash appears on the next boot"
}

do_remove() {
    msg "Removing the plymouth mkinitcpio hook"
    sudo sed -i -E '/^HOOKS=/{s/[[:space:]]+\bplymouth\b//; s/\bplymouth\b[[:space:]]+//}' "$MKINITCPIO"

    msg "Removing 'splash' from the systemd-boot entries"
    local entry
    for entry in "$ENTRIES"/*.conf; do
        [[ -f "$entry" ]] || continue
        sudo sed -i -E '/^options /{s/[[:space:]]+\bsplash\b//; s/\bsplash\b[[:space:]]+//}' "$entry"
    done

    msg "Unmasking the shutdown units"
    sudo systemctl unmask "${UNITS[@]}" 2>/dev/null || true

    msg "Deleting the -nologo theme clone(s)"
    sudo rm -rf "$THEMES"/*-nologo

    if pacman -Qq plymouth >/dev/null 2>&1; then
        msg "Uninstalling plymouth"
        sudo pacman -Rns --noconfirm plymouth
    else
        echo "plymouth is not installed"
    fi
    # -Rns drops the packaged config; make sure no stale copy points at a theme
    # that no longer exists.
    sudo rm -f /etc/plymouth/plymouthd.conf

    msg "Rebuilding the initramfs without the hook"
    sudo mkinitcpio -P

    msg "Done — plain quiet boot from the next start"
}

do_status() {
    if pacman -Qq plymouth >/dev/null 2>&1; then
        echo "package:  installed ($(pacman -Q plymouth | awk '{print $2}'))"
        echo "theme:    $(plymouth-set-default-theme 2>/dev/null || echo '?')"
    else
        echo "package:  not installed"
    fi
    if grep -Eq '^HOOKS=.*\bplymouth\b' "$MKINITCPIO"; then
        echo "hook:     present — $(grep '^HOOKS=' "$MKINITCPIO")"
    else
        echo "hook:     absent"
    fi
    local entry
    for entry in "$ENTRIES"/*.conf; do
        [[ -f "$entry" ]] || continue
        if grep -Eq '^options .*\bsplash\b' "$entry"; then
            echo "splash:   yes — $entry"
        else
            echo "splash:   no  — $entry"
        fi
    done
    local unit
    for unit in "${UNITS[@]}"; do
        echo "shutdown: $unit is $(systemctl is-enabled "$unit" 2>/dev/null || echo 'not found')"
    done
}

case "${1:-}" in
    install) do_install ;;
    remove)  do_remove ;;
    status)  do_status ;;
    *) echo "usage: $0 install|remove|status" >&2; exit 1 ;;
esac
