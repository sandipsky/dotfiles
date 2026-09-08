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
#      clone is built from whatever ImageDir the theme uses. The clone also
#      gets a bigger, lower spinner: the throbber-*.png frames are redrawn as
#      vectors at SPINNER_SIZE px (the two-step plugin has no scale key of its
#      own, and upscaling the 32 px originals looks blurry) and
#      VerticalAlignment is set to SPINNER_VALIGN.
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

# Spinner tweaks applied to the -nologo clone. Upstream frames are 32 px and
# sit at VerticalAlignment=.7 (0 = top edge, 1 = bottom edge of the screen).
SPINNER_SIZE=48
SPINNER_VALIGN=.76
SPINNER_FRAMES=30   # same count as upstream, so the rotation speed is unchanged

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

# One frame of the GNOME/Adwaita spinner as SVG on stdout (frame 1..SPINNER_FRAMES).
# Geometry is measured from the upstream 32 px throbber-*.png frames: a 4-unit
# ring of radius 9.5 on a 32-unit canvas, the track in #7c7c7c at 24 %
# opacity, and a white 96° arc with round caps that advances
# 360/SPINNER_FRAMES degrees per frame (clockwise, starting near 3 o'clock).
# Rendering the SVG at SPINNER_SIZE gives crisp edges at any size.
spinner_frame_svg() {
    awk -v n="$1" -v frames="$SPINNER_FRAMES" 'BEGIN {
        pi = atan2(0, -1); r = 9.5; sweep = 96
        start = -6 + (n - 1) * 360 / frames
        a0 = start * pi / 180; a1 = (start + sweep) * pi / 180
        printf "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 32\">\n"
        printf "<circle cx=\"16\" cy=\"16\" r=\"%s\" fill=\"none\" stroke=\"#7c7c7c\" stroke-opacity=\"0.243\" stroke-width=\"4\"/>\n", r
        printf "<path d=\"M %.4f %.4f A %s %s 0 0 1 %.4f %.4f\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"4\" stroke-linecap=\"round\"/>\n", \
            16 + r * cos(a0), 16 + r * sin(a0), r, r, 16 + r * cos(a1), 16 + r * sin(a1)
        printf "</svg>\n"
    }'
}

do_install() {
    msg "Installing plymouth (and librsvg, whose rsvg-convert renders the spinner frames)"
    sudo pacman -S --noconfirm --needed plymouth librsvg

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
        -e "s|^VerticalAlignment=.*|VerticalAlignment=$SPINNER_VALIGN|" \
        "$src_conf" | sudo tee "$dst/$theme-nologo.plymouth" >/dev/null
    if ! grep -q '^ImageDir=' "$dst/$theme-nologo.plymouth"; then
        sudo sed -i "/^\[two-step\]/a ImageDir=$dst" "$dst/$theme-nologo.plymouth"
    fi
    if ! grep -q '^VerticalAlignment=' "$dst/$theme-nologo.plymouth"; then
        sudo sed -i "/^\[two-step\]/a VerticalAlignment=$SPINNER_VALIGN" "$dst/$theme-nologo.plymouth"
    fi

    # Bigger spinner: the two-step plugin draws the throbber-*.png frames at
    # their pixel size, so replace the clone's copies with frames rendered
    # from vector art at SPINNER_SIZE (the package's own frames stay untouched).
    if compgen -G "$dst/throbber-*.png" >/dev/null; then
        msg "Rendering $SPINNER_FRAMES spinner frames at ${SPINNER_SIZE}px, VerticalAlignment=$SPINNER_VALIGN"
        local tmp i name
        tmp=$(mktemp -d)
        for ((i = 1; i <= SPINNER_FRAMES; i++)); do
            name=$(printf 'throbber-%04d' "$i")
            spinner_frame_svg "$i" > "$tmp/$name.svg"
            rsvg-convert -w "$SPINNER_SIZE" -h "$SPINNER_SIZE" "$tmp/$name.svg" -o "$tmp/$name.png"
        done
        sudo rm -f "$dst"/throbber-*.png
        sudo cp "$tmp"/throbber-*.png "$dst/"
        rm -rf "$tmp"
    else
        echo "theme has no throbber-*.png frames — spinner size left as is"
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
