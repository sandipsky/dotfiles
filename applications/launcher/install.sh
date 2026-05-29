#!/usr/bin/env bash
# Install script for the Launcher app.
# Checks dependencies, installs any that are missing, builds and installs to
# ~/.local, enables the resident systemd user service, and binds Alt+Space.

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
    err "glib2 gtk4 libadwaita wl-clipboard, then run:"
    err "  meson setup build --prefix=\$HOME/.local && meson install -C build"
    exit 1
fi

# --- Dependency check ---------------------------------------------------

REQUIRED_PKGS=(
    meson
    ninja
    gcc
    pkgconf
    glib2          # provides glib-compile-resources
    gtk4
    libadwaita
    wl-clipboard   # calculator results are copied via wl-copy
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

# --- Post-install: refresh icon cache ----------------------------------

ICON_DIR="$PREFIX/share/icons/hicolor"

if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ -d "$ICON_DIR" ]]; then
    info "Refreshing GTK icon cache"
    # -q quiet, -t force-load (allows updating user theme without write to system),
    # -f even if cache appears up to date. Ignore failure (cache is optional for SVGs).
    gtk-update-icon-cache -q -t -f "$ICON_DIR" 2>/dev/null || true
fi

BIN="$PREFIX/bin/launcher"
if [[ ! -x "$BIN" ]]; then
    err "Installed binary not found at $BIN"
    exit 1
fi

# --- Enable the resident service ---------------------------------------
# Symlink it into graphical-session.target.wants so it starts on every login.
# We create the symlink directly (rather than `systemctl --user enable`) so this
# works even when run from a tty with no user systemd manager — e.g. when driven
# by gnome.sh before the first graphical login.

info "Enabling launcher.service (starts on login)"
UNIT_SRC="$PREFIX/share/systemd/user/launcher.service"
WANTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/graphical-session.target.wants"
mkdir -p "$WANTS_DIR"
ln -sf "$UNIT_SRC" "$WANTS_DIR/launcher.service"

# If a user systemd manager is reachable, reload + start it now too.
if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user daemon-reload || true
    systemctl --user start launcher.service || true
    dim "service started"
else
    dim "no user session bus — service will start at next login"
fi

# --- Bind Alt+Space -----------------------------------------------------
# A GNOME custom keybinding running `launcher --toggle`, which forwards to the
# resident instance. Alt+Space is GNOME's window-menu shortcut by default, so we
# free that first. Settings are written to dconf and persist across sessions.

KEY_CMD="$BIN --toggle"
setup_keybinding () {
    local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/launcher/"
    local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path}"

    gsettings set org.gnome.desktop.wm.keybindings activate-window-menu "[]" || true

    local existing
    existing="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo '@as []')"
    if [[ "$existing" != *"$path"* ]]; then
        if [[ "$existing" == "@as []" || "$existing" == "[]" || -z "$existing" ]]; then
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$path']"
        else
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${existing%]*}, '$path']"
        fi
    fi
    gsettings set "$schema" name 'Launcher'
    gsettings set "$schema" command "$KEY_CMD"
    gsettings set "$schema" binding '<Alt>space'
}

info "Binding Alt+Space to the launcher"
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    setup_keybinding
elif command -v dbus-run-session >/dev/null 2>&1; then
    # No live session bus (tty install): write straight to dconf via a throwaway bus.
    export -f setup_keybinding
    export KEY_CMD
    dbus-run-session -- bash -c setup_keybinding
else
    warn "Could not set the keybinding (no D-Bus). Set it manually:"
    warn "  Settings -> Keyboard -> Custom Shortcuts -> Command: $KEY_CMD , Shortcut: Alt+Space"
fi

# --- Done ---------------------------------------------------------------

info "Done."
dim "Binary:    $BIN"
dim "Service:   $UNIT_SRC  (-> $WANTS_DIR)"
dim "Keybind:   Alt+Space -> $KEY_CMD"
echo
echo "The launcher runs hidden in the background and pops up on Alt+Space."
echo "Start it now without logging out:"
echo "    systemctl --user start launcher.service"
