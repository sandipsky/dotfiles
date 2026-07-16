#!/bin/bash
# Restore the vendored Noctalia v4 fork (Quickshell/QML) after trying the v5
# beta with noctalia5.sh. Inverse of that script.
#
# Run as your normal user: ./noctalia4.sh   (sudo-prompts only for pacman)
#
# What it does:
#   1. Reinstalls the `noctalia-qs` Quickshell runtime FIRST (AUR, falling back
#      to building the vendored copy in assets/noctalia-qs/ like install.sh),
#      so the machine is never left without a shell if the install fails.
#   2. Restores the LIVE Hyprland config (~/.config/hypr/conf/): prefers the
#      *.v4bak backups noctalia5.sh made, else copies the repo's v4 files.
#   3. Stops Noctalia v5 and removes its `noctalia` package.
#   4. Hands off to ./reset.sh, which syncs config/quickshell/noctalia-shell/
#      to ~/.config/quickshell/noctalia-shell/ and starts the v4 shell.
#
# Not touched: v5's settings (~/.config/noctalia/*.toml and
# ~/.local/state/noctalia/settings.toml) stay on disk, ignored by v4 - so you
# can hop back to v5 later without reconfiguring. v4's settings.json was never
# deleted by noctalia5.sh, so your v4 runtime settings come back as they were.

set -e

if [[ $EUID -eq 0 ]]; then
    echo "Run noctalia4.sh as your normal user, not with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYPR_CONF="$HOME/.config/hypr/conf"

if [[ ! -d "$SCRIPT_DIR/config/quickshell/noctalia-shell" ]]; then
    echo "Vendored fork not found at $SCRIPT_DIR/config/quickshell/noctalia-shell - aborting." >&2
    exit 1
fi

# --- 1. Reinstall the v4 Quickshell runtime -----------------------------------
if ! pacman -Qq noctalia-qs >/dev/null 2>&1; then
    if ! yay -S --noconfirm --needed noctalia-qs; then
        BUILD_DIR=$(mktemp -d)
        cp -r "$SCRIPT_DIR/assets/noctalia-qs/." "$BUILD_DIR/"
        (cd "$BUILD_DIR" && makepkg -s --noconfirm)
        sudo pacman -U --noconfirm "$BUILD_DIR"/noctalia-qs-0*.pkg.tar.zst
        rm -rf "$BUILD_DIR"
    fi
fi

if ! command -v qs >/dev/null 2>&1; then
    echo "qs binary not found after installing noctalia-qs - aborting before touching v5." >&2
    exit 1
fi

# --- 2. Restore the live Hyprland config to v4 --------------------------------
for f in autostart.conf keybinds.conf; do
    if [[ -f "$HYPR_CONF/$f.v4bak" ]]; then
        mv "$HYPR_CONF/$f.v4bak" "$HYPR_CONF/$f"
    else
        # No backup (or already consumed) - the repo copy is the v4 source of truth
        cp "$SCRIPT_DIR/config/hypr/conf/$f" "$HYPR_CONF/$f"
    fi
done

if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null
fi

# --- 3. Stop and remove Noctalia v5 -------------------------------------------
pkill -x noctalia || true
for _ in $(seq 1 20); do
    pgrep -x noctalia >/dev/null || break
    sleep 0.2
done

if pacman -Qq noctalia >/dev/null 2>&1; then
    sudo pacman -R --noconfirm noctalia
fi

# --- 4. Sync the fork and start the v4 shell -----------------------------------
# reset.sh does the rest: replaces ~/.config/quickshell/noctalia-shell with the
# repo tree, removes a stray AUR noctalia-shell package if one exists, and
# starts qs -c noctalia-shell (verifying it comes up).
exec "$SCRIPT_DIR/reset.sh"
