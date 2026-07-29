#!/usr/bin/env bash
# Ubuntu counterpart of rebuild-nautilus.sh: rebuild the vendored Nautilus
# fork (applications/nautilus-fork/nautilus) and install it ON TOP of the
# stock Ubuntu nautilus package — nothing is removed or replaced.
#
# How the overlay works: everything installs under /usr/local, which outranks
# /usr everywhere that matters — PATH (/usr/local/bin/nautilus), XDG_DATA_DIRS
# (.desktop file, GSettings schema, D-Bus activation service) and the dynamic
# linker (/usr/local/lib/... comes first in ld.so.conf). The stock package
# stays installed for its runtime deps but its binary never runs.
#
# Run as your user: ./rebuild-nautilus-ubuntu.sh
# (sudo-prompts only for the install step)
#
# The build dir is persistent (~/.cache/nautilus-fork-build), so after the
# first full compile only changed files rebuild — much faster iteration.
#
# To go back to stock nautilus, just delete the overlay:
#   sudo rm -f /usr/local/bin/nautilus* \
#       /usr/local/share/applications/org.gnome.Nautilus*.desktop \
#       /usr/local/share/dbus-1/services/org.gnome.Nautilus*.service \
#       /usr/local/share/glib-2.0/schemas/org.gnome.nautilus.gschema.xml \
#       /usr/local/lib/*/libnautilus-extension*
#   sudo glib-compile-schemas /usr/local/share/glib-2.0/schemas && sudo ldconfig
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your user, not with sudo (it sudo-prompts when needed)."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/applications/nautilus-fork/nautilus"
BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nautilus-fork-build"

if [[ ! -f "$BUILD_DIR/build.ninja" ]]; then
    meson setup "$BUILD_DIR" "$SRC_DIR" \
        --prefix=/usr/local \
        -D docs=false \
        -D packagekit=false \
        -D selinux=false
fi

meson compile -C "$BUILD_DIR"
sudo meson install -C "$BUILD_DIR"
sudo ldconfig

# meson install rewrites the .desktop file, undoing ubuntu.sh's custom-icon
# repoint (Yaru outranks hicolor, so the icon must be an absolute path).
ICON="/usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg"
if [[ -f "$ICON" ]]; then
    sudo sed -i "s|^Icon=.*|Icon=$ICON|" \
        /usr/local/share/applications/org.gnome.Nautilus.desktop
    sudo update-desktop-database /usr/local/share/applications 2>/dev/null || true
fi

# Quit the running instance so the next launch picks up the new binary.
nautilus -q 2>/dev/null || true

echo "Done. Fork installed to /usr/local (stock package untouched)."
