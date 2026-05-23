#!/usr/bin/env bash
# Install script for the Music app.
# Checks dependencies, installs any that are missing, builds, and installs to
# ~/.local so the binary and the .desktop entry land in your user dirs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PREFIX="${PREFIX:-$HOME/.local}"

# ANSI colors (skip if not a tty)
if [[ -t 1 ]]; then
    C_BOLD=$'\033[1m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
    C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_RESET=""
fi

info()  { printf '%s==>%s %s\n' "$C_BOLD$C_GREEN"   "$C_RESET" "$*"; }
warn()  { printf '%s==>%s %s\n' "$C_BOLD$C_YELLOW"  "$C_RESET" "$*"; }
err()   { printf '%s==>%s %s\n' "$C_BOLD$C_RED"     "$C_RESET" "$*" >&2; }
dim()   { printf '%s    %s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# --- Distro detection ----------------------------------------------------

if ! command -v pacman >/dev/null 2>&1; then
    err "This installer assumes Arch Linux (pacman not found)."
    err "On other distros, install the equivalents of: meson ninja gcc pkgconf"
    err "gtk4 libadwaita gstreamer gst-plugins-base gst-plugins-good"
    err "gst-plugins-bad gst-libav, then run:"
    err "  meson setup build --prefix=\$HOME/.local && meson install -C build"
    exit 1
fi

# --- Dependency check ---------------------------------------------------

REQUIRED_PKGS=(
    meson
    ninja
    gcc
    pkgconf
    gtk4
    libadwaita
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-libav
    desktop-file-utils
    hicolor-icon-theme
)

info "Checking dependencies"
MISSING=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        dim "[ok]      $pkg"
    else
        dim "[missing] $pkg"
        MISSING+=("$pkg")
    fi
done

if (( ${#MISSING[@]} > 0 )); then
    warn "Missing packages: ${MISSING[*]}"
    read -r -p "Install them with sudo pacman -S? [Y/n] " ANSWER
    ANSWER="${ANSWER:-Y}"
    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
        err "Cannot continue without these packages."
        exit 1
    fi
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
else
    info "All dependencies satisfied"
fi

# --- Configure ----------------------------------------------------------

if [[ ! -d "$BUILD_DIR" ]]; then
    info "Configuring build ($BUILD_DIR, prefix=$PREFIX)"
    meson setup "$BUILD_DIR" --prefix="$PREFIX"
else
    info "Reconfiguring build (prefix=$PREFIX)"
    meson setup --reconfigure "$BUILD_DIR" --prefix="$PREFIX"
fi

# --- Compile ------------------------------------------------------------

info "Compiling"
meson compile -C "$BUILD_DIR"

# --- Install ------------------------------------------------------------

info "Installing to $PREFIX"
meson install -C "$BUILD_DIR"

# --- Post-install: refresh desktop database + icon cache ---------------

DESKTOP_DIR="$PREFIX/share/applications"
ICON_DIR="$PREFIX/share/icons/hicolor"

if command -v update-desktop-database >/dev/null 2>&1 && [[ -d "$DESKTOP_DIR" ]]; then
    info "Refreshing desktop database"
    update-desktop-database "$DESKTOP_DIR"
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ -d "$ICON_DIR" ]]; then
    info "Refreshing GTK icon cache"
    # -q quiet, -t force-load (allows updating user theme without write to system),
    # -f even if cache appears up to date. Ignore failure (cache is optional for SVGs).
    gtk-update-icon-cache -q -t -f "$ICON_DIR" 2>/dev/null || true
fi

# --- PATH check ---------------------------------------------------------

BIN="$PREFIX/bin/music"
if [[ ! -x "$BIN" ]]; then
    err "Installed binary not found at $BIN"
    exit 1
fi

if ! command -v music >/dev/null 2>&1; then
    warn "$PREFIX/bin is not on your \$PATH."
    warn "Add this to your shell rc (~/.zshrc or ~/.bashrc):"
    echo
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
    warn "Then reload with: source ~/.zshrc"
fi

# --- Done ---------------------------------------------------------------

info "Done."
dim "Binary:       $BIN"
dim "Desktop file: $DESKTOP_DIR/dev.sandip.Music.desktop"
dim "Color icon:   $ICON_DIR/scalable/apps/dev.sandip.Music.svg"
dim "Symbolic:     $ICON_DIR/symbolic/apps/dev.sandip.Music-symbolic.svg"
echo
echo "Launch with:"
echo "    music"
echo
echo "Right-click an audio file in your file manager → Open With → Music"
echo
echo "Make it the default for common audio types (optional):"
echo "    xdg-mime default dev.sandip.Music.desktop \\"
echo "        audio/mpeg audio/flac audio/ogg audio/mp4 \\"
echo "        audio/x-m4a audio/opus audio/wav audio/aac"
