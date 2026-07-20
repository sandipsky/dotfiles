#!/bin/bash
set -e

if [[ $EUID -eq 0 ]]; then
    echo "Run rebuild-nautilus.sh as your normal user, not with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The fork has "Open in Terminal" / "Open in Code" built in — remove the
# third-party extensions so the menu items don't show up twice. (-R without
# --cascade never removes dependent packages; it just fails if any exist.)
if pacman -Qq nautilus-open-any-terminal >/dev/null 2>&1; then
    sudo pacman -R --noconfirm nautilus-open-any-terminal
fi
rm -f "$HOME/.local/share/nautilus-python/extensions/code-nautilus.py"

# DE-safety: the fork replaces the official nautilus package IN PLACE (same
# package name, provides libnautilus-extension.so), so anything that depends
# on nautilus — a full GNOME desktop included — keeps its dependency
# satisfied. Never silently downgrade, though: on a system whose installed
# nautilus is newer than the vendored fork (e.g. GNOME got updated), the
# right move is bumping the vendored tree (see docs/nautilus-patches.md),
# not forcing an older build onto a newer GNOME stack.
FORK_VER=$(sed -n 's/^pkgver=//p' "$SCRIPT_DIR/applications/nautilus-fork/PKGBUILD")
INSTALLED_VER=$(pacman -Q nautilus 2>/dev/null | awk '{print $2}' || true)

if [[ -n "$INSTALLED_VER" ]] && [[ "$(vercmp "${INSTALLED_VER%-*}" "$FORK_VER")" -gt 0 ]]; then
    echo "WARNING: installed nautilus ${INSTALLED_VER} is NEWER than the vendored fork (${FORK_VER})." >&2
    echo "Installing would DOWNGRADE nautilus under the rest of the desktop stack." >&2
    echo "Prefer bumping the vendored tree first (docs/nautilus-patches.md, 'Bumping upstream')." >&2
    read -r -p "Downgrade anyway? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Build the vendored fork only — the source tree in applications/nautilus-fork/
# (upstream + local patches, see docs/nautilus-patches.md) is the sole source;
# nothing is fetched from the Arch repos, AUR, or the network.
# The fork builds as the same "nautilus" package with a higher pkgrel, so
# pacman -U below replaces the official package in place — no -R needed.
BUILD_DIR=$(mktemp -d)
cp -r "$SCRIPT_DIR/applications/nautilus-fork/." "$BUILD_DIR/"
(cd "$BUILD_DIR" && makepkg -s --noconfirm)

# Deliberately NOT --noconfirm: if pacman ever proposes removing conflicting
# packages here, it must be shown and explicitly confirmed, never auto-agreed.
# A normal run only shows the two fork packages as targets.
sudo pacman -U "$BUILD_DIR"/nautilus-*.pkg.tar.zst "$BUILD_DIR"/libnautilus-extension-*.pkg.tar.zst
rm -rf "$BUILD_DIR"

# Keep pacman -Syu from replacing the fork with the repo package.
if ! grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*nautilus' /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a IgnorePkg = nautilus libnautilus-extension' /etc/pacman.conf
fi

# Quit any running instance so the next launch uses the new binary. Safe on
# GNOME too: nautilus hasn't drawn the desktop since 3.28 and is D-Bus
# activated, so it simply restarts on next use.
nautilus -q >/dev/null 2>&1 || true

echo "Nautilus fork installed: $(pacman -Q nautilus)"
