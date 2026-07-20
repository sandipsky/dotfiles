#!/bin/bash
set -e

if [[ $EUID -eq 0 ]]; then
    echo "Run reset.sh as your normal user, not with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if pacman -Qq noctalia-shell >/dev/null 2>&1; then
    sudo pacman -D --asexplicit noctalia-qs
    sudo pacman -R --noconfirm noctalia-shell
fi

# Build the vendored recipe only — the AUR noctalia-qs is unmaintained
# (upstream discontinued the fork when v5 dropped Quickshell).
if ! pacman -Qq noctalia-qs >/dev/null 2>&1; then
    BUILD_DIR=$(mktemp -d)
    cp -r "$SCRIPT_DIR/applications/noctalia-qs/." "$BUILD_DIR/"
    (cd "$BUILD_DIR" && makepkg -s --noconfirm)
    sudo pacman -U --noconfirm "$BUILD_DIR"/noctalia-qs-0*.pkg.tar.zst
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$HOME/.config/quickshell"
rm -rf "$HOME/.config/quickshell/noctalia-shell.new"
cp -r "$SCRIPT_DIR/config/quickshell/noctalia-shell" "$HOME/.config/quickshell/noctalia-shell.new"
rm -rf "$HOME/.config/quickshell/noctalia-shell"
mv "$HOME/.config/quickshell/noctalia-shell.new" "$HOME/.config/quickshell/noctalia-shell"

pkill -f '(^|/)qs -c noctalia-shell' || true
for _ in $(seq 1 20); do
    pgrep -f '(^|/)qs -c noctalia-shell' >/dev/null || break
    sleep 0.2
done

qs -c noctalia-shell -d
sleep 1

if pgrep -f '(^|/)qs -c noctalia-shell' >/dev/null; then
    echo "Noctalia restarted from $HOME/.config/quickshell/noctalia-shell"
else
    echo "Noctalia failed to start - run 'qs -c noctalia-shell' to see errors." >&2
    exit 1
fi
