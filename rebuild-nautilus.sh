#!/bin/bash
set -e

if [[ $EUID -eq 0 ]]; then
    echo "Run rebuild-nautilus.sh as your normal user, not with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The fork has "Open in Terminal" / "Open in Code" built in — remove the
# third-party extensions so the menu items don't show up twice.
if pacman -Qq nautilus-open-any-terminal >/dev/null 2>&1; then
    sudo pacman -R --noconfirm nautilus-open-any-terminal
fi
rm -f "$HOME/.local/share/nautilus-python/extensions/code-nautilus.py"

# Build the vendored fork only — the source tree in applications/nautilus-fork/
# (upstream + local patches, see docs/nautilus-patches.md) is the sole source;
# nothing is fetched from the Arch repos, AUR, or the network.
# The fork builds as the same "nautilus" package with a higher pkgrel, so
# pacman -U below replaces the official package in place — no -R needed.
BUILD_DIR=$(mktemp -d)
cp -r "$SCRIPT_DIR/applications/nautilus-fork/." "$BUILD_DIR/"
(cd "$BUILD_DIR" && makepkg -s --noconfirm)
sudo pacman -U --noconfirm "$BUILD_DIR"/nautilus-*.pkg.tar.zst "$BUILD_DIR"/libnautilus-extension-*.pkg.tar.zst
rm -rf "$BUILD_DIR"

# Keep pacman -Syu from replacing the fork with the repo package.
if ! grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*nautilus' /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a IgnorePkg = nautilus libnautilus-extension' /etc/pacman.conf
fi

# Quit any running instance so the next launch uses the new binary.
nautilus -q >/dev/null 2>&1 || true

echo "Nautilus fork installed: $(pacman -Q nautilus)"
