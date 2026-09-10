#!/bin/bash
# office.sh — add or remove LibreOffice on a system installed by install.sh
# (or kde.sh), with only Writer, Calc and Impress showing in the launcher.
#
#   ./scripts/office.sh install   libreoffice-fresh + launcher entries trimmed
#   ./scripts/office.sh remove    undo everything install did, uninstall LibreOffice
#   ./scripts/office.sh status    show what is currently in place
#
# Run as your normal user; the package step uses sudo. install.sh calls
# `install` when its LibreOffice prompt is answered yes — this is the same
# code — and both modes also work on an already-set-up machine.
#
# What `install` does:
#   1. pacman -S libreoffice-fresh
#   2. hides every libreoffice-*.desktop except Writer, Calc and Impress from
#      the launcher (Start Center, Base, Draw, Math, the XSLT filter dialog)
#      with NoDisplay=true overrides in ~/.local/share/applications — copies
#      of the system files, so the entries still resolve for MIME handling.
#      The plain "append NoDisplay=true" trick install.sh uses for other apps
#      doesn't work here: these files end with a [Desktop Action] section (an
#      appended key would land in the wrong section), and startcenter/math
#      ship an explicit NoDisplay=false that overrides any earlier
#      NoDisplay=true (GKeyFile takes the last occurrence of a key). So the
#      key is inserted as the last key of [Desktop Entry], right before the
#      Actions= line.
#
# `remove` reverses that: the overrides are deleted (only files this script
# wrote — libreoffice-*.desktop in the user dir that carry the marker
# comment, or that are a plain copy of the system file plus NoDisplay=true,
# which is what older install.sh runs wrote), then pacman -Rns
# libreoffice-fresh. The user profile in
# ~/.config/libreoffice (settings, recent documents, macros) is left alone
# so a later reinstall picks it back up; delete it by hand if unwanted.
#
# Every step is idempotent — re-running either mode is harmless, and `install`
# after a LibreOffice upgrade re-trims any new .desktop files.

set -e

PKG=libreoffice-fresh
SYSTEM_APPS=/usr/share/applications
APPS_DIR="$HOME/.local/share/applications"
VISIBLE=(libreoffice-writer.desktop libreoffice-calc.desktop libreoffice-impress.desktop)
# Written into every override so `remove` never touches a .desktop the user
# created themselves.
MARKER='# hidden by dotfiles/scripts/office.sh'

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "run this as your normal user, not with sudo — the launcher overrides go into your home"

is_visible() {
    local v
    for v in "${VISIBLE[@]}"; do
        [[ "$1" == "$v" ]] && return 0
    done
    return 1
}

# An override in $APPS_DIR that this script (or the old inline loop in
# install.sh, which wrote no marker) produced: carries the marker, or differs
# from the system file only by NoDisplay=true. Anything else is the user's.
is_ours() {
    local f=$1 sys="$SYSTEM_APPS/$(basename "$1")"
    grep -qF "$MARKER" "$f" && return 0
    [[ -f "$sys" ]] || return 1
    # Strip those lines from both sides — xsltfilter ships NoDisplay=true itself.
    diff -q <(grep -vxF -e "$MARKER" -e 'NoDisplay=true' "$f") \
            <(grep -vxF -e "$MARKER" -e 'NoDisplay=true' "$sys") >/dev/null
}

# The .desktop files install hides (whatever the installed package ships).
hidden_entries() {
    local src name
    for src in "$SYSTEM_APPS"/libreoffice-*.desktop; do
        [[ -f "$src" ]] || continue
        name=$(basename "$src")
        is_visible "$name" || echo "$name"
    done
}

do_install() {
    msg "Installing $PKG"
    sudo pacman -S --noconfirm --needed "$PKG"

    msg "Hiding everything but Writer, Calc and Impress from the launcher"
    mkdir -p "$APPS_DIR"
    local name src dest
    while read -r name; do
        src="$SYSTEM_APPS/$name"
        dest="$APPS_DIR/$name"
        cp "$src" "$dest"
        if grep -q '^Actions=' "$dest"; then
            sed -i -e "/^Actions=/i $MARKER" -e '/^Actions=/i NoDisplay=true' "$dest"
        else
            printf '%s\nNoDisplay=true\n' "$MARKER" >> "$dest"
        fi
        echo "hidden: $name"
    done < <(hidden_entries)
    # Stale overrides for entries the package no longer ships would keep
    # pointing at a missing Exec — drop them.
    for dest in "$APPS_DIR"/libreoffice-*.desktop; do
        [[ -f "$dest" ]] || continue
        grep -qF "$MARKER" "$dest" || continue
        [[ -f "$SYSTEM_APPS/$(basename "$dest")" ]] || rm -f "$dest"
    done
    command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true

    msg "Done — LibreOffice installed; Writer, Calc and Impress in the launcher"
}

do_remove() {
    msg "Removing the launcher overrides"
    local dest removed=0
    for dest in "$APPS_DIR"/libreoffice-*.desktop; do
        [[ -f "$dest" ]] || continue
        if is_ours "$dest"; then
            rm -f "$dest"
            echo "removed: $(basename "$dest")"
            removed=1
        else
            echo "kept:    $(basename "$dest") (not written by this script)"
        fi
    done
    [[ $removed -eq 1 ]] || echo "no overrides present"
    command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true

    if pacman -Qq "$PKG" >/dev/null 2>&1; then
        msg "Uninstalling $PKG"
        sudo pacman -Rns --noconfirm "$PKG"
    else
        echo "$PKG is not installed"
    fi

    msg "Done — LibreOffice removed"
    [[ -d "$HOME/.config/libreoffice" ]] && echo "note: the user profile in ~/.config/libreoffice was kept; rm -rf it if you don't want it back on a reinstall"
    return 0
}

do_status() {
    if pacman -Qq "$PKG" >/dev/null 2>&1; then
        echo "package:  installed ($(pacman -Q "$PKG" | awk '{print $2}'))"
    else
        echo "package:  not installed"
    fi
    local name dest
    for name in "${VISIBLE[@]}"; do
        if [[ -f "$SYSTEM_APPS/$name" ]]; then
            echo "visible:  $name"
        fi
    done
    while read -r name; do
        dest="$APPS_DIR/$name"
        if [[ -f "$dest" ]] && is_ours "$dest"; then
            echo "hidden:   $name"
        else
            echo "shown:    $name — no override in $APPS_DIR"
        fi
    done < <(hidden_entries)
    for dest in "$APPS_DIR"/libreoffice-*.desktop; do
        [[ -f "$dest" ]] || continue
        grep -qF "$MARKER" "$dest" || continue
        [[ -f "$SYSTEM_APPS/$(basename "$dest")" ]] || echo "stale:    $(basename "$dest") — override without a system entry"
    done
    if [[ -d "$HOME/.config/libreoffice" ]]; then
        echo "profile:  ~/.config/libreoffice present"
    else
        echo "profile:  none"
    fi
}

case "${1:-}" in
    install) do_install ;;
    remove)  do_remove ;;
    status)  do_status ;;
    *) echo "usage: $0 install|remove|status" >&2; exit 1 ;;
esac
