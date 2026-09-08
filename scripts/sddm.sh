#!/bin/bash
# sddm.sh — switch the Hyprland box between SDDM (with the Elegant theme)
# and install.sh's direct login (tty1 autologin + .zprofile exec into Hyprland).
#
#   ./scripts/sddm.sh [install]   SDDM + Elegant theme; direct login removed
#   ./scripts/sddm.sh uninstall   SDDM removed; direct login restored
#   ./scripts/sddm.sh status      show what is currently in place
#
# Run as your normal user; system steps use sudo. install.sh calls `install`
# when its SDDM prompt is answered yes — this is the same code — and both
# modes also work on an already-set-up machine, so you can switch either way
# later. Nothing is started or stopped live (that would kill the running
# session): changes take effect at the next boot.
#
# What `install` does:
#   1. pacman -S sddm (Qt6 on Arch) + qt6-5compat — the theme's blur/glow
#      effects come from Qt5Compat.GraphicalEffects (the vendored theme was
#      ported from Qt5's QtGraphicalEffects, see the imports in
#      assets/sddm-themes/Elegant/*.qml),
#      plus ttf-fira-sans — the theme renders in Fira Sans (icons come from
#      the Tabler icon font bundled in the theme's fonts/)
#   2. copies assets/sddm-themes/Elegant/ to /usr/share/sddm/themes/, writes
#      its theme.conf.user with hypr-shell's ui.accent (live config.json, else
#      the repo snapshot — the theme derives its palette from it like the
#      shell does) and selects it via a drop-in in /etc/sddm.conf.d/ (Arch
#      ships no /etc/sddm.conf), together with the desktop's cursor
#      (BreezeX-Light, 24 — breezex-cursor-theme from the AUR, installed via
#      yay if missing; xorg-xsetroot so sddm can actually apply it to the X
#      root window, and the same XCURSOR_* in GreeterEnvironment)
#   3. installs assets/profile.png as the user's SDDM avatar in
#      /usr/share/sddm/faces/ — the greeter runs as the sddm user and can't
#      read ~/.face.icon inside a 0700 home
#   4. preselects the user and the uwsm-managed Hyprland session in SDDM's
#      state file, so the first login matches what the tty path launched
#   5. removes the direct-login pieces install.sh set up: the getty@tty1
#      autologin override and the `uwsm start` block in the login profile
#   6. systemctl enable sddm.service (sddm.service conflicts with
#      getty@tty1.service, so it owns tty1 from the next boot)
#
# `uninstall` reverses that: sddm.service disabled, theme/drop-in/avatar/state
# gone, pacman -Rns sddm (and qt6-5compat if nothing else needs it), then the
# getty@tty1 override and profile block are put back exactly as install.sh
# writes them — keep those two heredocs in sync with install.sh.
#
# Every step is idempotent — re-running either mode is harmless.

set -e

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
THEME_SRC=$REPO_DIR/assets/sddm-themes
USERNAME=$(logname)

THEME=Elegant
# Same cursor the desktop uses (environment.lua, gtk-3.0/settings.ini, gsettings).
CURSOR_THEME=BreezeX-Light
CURSOR_SIZE=24
THEMES_DIR=/usr/share/sddm/themes
FACES_DIR=/usr/share/sddm/faces
CONF_DIR=/etc/sddm.conf.d
THEME_CONF=$CONF_DIR/10-theme.conf
STATE_FILE=/var/lib/sddm/state.conf
UWSM_SESSION=/usr/share/wayland-sessions/hyprland-uwsm.desktop
GETTY_DIR=/etc/systemd/system/getty@tty1.service.d
GETTY_OVERRIDE=$GETTY_DIR/override.conf

# Same shell-dependent profile install.sh writes its autostart block to.
LOGIN_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
if [[ "$(basename "$LOGIN_SHELL")" == "zsh" ]]; then
    PROFILE="/home/$USERNAME/.zprofile"
else
    PROFILE="/home/$USERNAME/.bash_profile"
fi
# First line of that block — used to detect and to delete it (the range runs
# to the first unindented `fi`, i.e. the block's own closing one).
PROFILE_START='if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then'

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ $EUID -eq 0 ]]; then
    die "run this as your normal user, not with sudo — it calls sudo itself"
fi

has_profile_block() {
    [[ -f "$PROFILE" ]] && grep -qF -- "$PROFILE_START" "$PROFILE"
}

remove_direct_login() {
    msg "Removing the tty1 autologin override"
    if [[ -f "$GETTY_OVERRIDE" ]]; then
        sudo rm -f "$GETTY_OVERRIDE"
        sudo rmdir --ignore-fail-on-non-empty "$GETTY_DIR"
        sudo systemctl daemon-reload
    else
        echo "not present"
    fi

    msg "Removing the Hyprland autostart block from $PROFILE"
    if has_profile_block; then
        sed -i "/^$(printf '%s' "$PROFILE_START" | sed 's/[][\\.*^$|]/\\&/g; s|/|\\/|g')$/,/^fi$/d" "$PROFILE"
    else
        echo "not present"
    fi
}

# Mirrors install.sh's direct-login steps — keep in sync.
restore_direct_login() {
    msg "Restoring the tty1 autologin override"
    sudo mkdir -p "$GETTY_DIR"
    sudo tee "$GETTY_OVERRIDE" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --skip-login --nonewline --noissue --noclear %I \$TERM
Type=idle
EOF
    sudo systemctl daemon-reload

    msg "Restoring the Hyprland autostart block in $PROFILE"
    if has_profile_block; then
        echo "already present"
    else
        tee -a "$PROFILE" >/dev/null <<'EOF'
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
    if uwsm check may-start; then
        exec uwsm start hyprland.desktop >/dev/null 2>&1
    fi
fi
EOF
    fi
}

do_install() {
    [[ -d "$THEME_SRC/$THEME" ]] || die "theme directory $THEME_SRC/$THEME not found"

    msg "Installing sddm, qt6-5compat, xsetroot and the theme font"
    # ttf-fira-sans: the theme renders in Fira Sans (the desktop's interface
    # font). xorg-xsetroot: sddm applies CursorTheme to the X root window by
    # running `xsetroot -cursor_name left_ptr`; without it the journal shows
    # "Could not setup default cursor" and the greeter keeps X's stock cursor.
    sudo pacman -S --noconfirm --needed sddm ttf-fira-sans xorg-xsetroot
    # As a dependency, so `uninstall` can drop it again once nothing needs it.
    sudo pacman -S --noconfirm --needed --asdeps qt6-5compat

    msg "Installing the $THEME theme to $THEMES_DIR"
    sudo mkdir -p "$THEMES_DIR"
    # Keep what hypr-shell-settings' "Login screen" page wrote into the theme
    # dir (theme.conf.user and a copied background image) across the re-copy.
    local keep f
    keep=$(mktemp -d)
    for f in "$THEMES_DIR/$THEME"/theme.conf.user "$THEMES_DIR/$THEME"/background.*; do
        [[ -f "$f" ]] && sudo cp -p "$f" "$keep/"
    done
    sudo rm -rf "$THEMES_DIR/$THEME"
    sudo cp -r "$THEME_SRC/$THEME" "$THEMES_DIR/"
    for f in "$keep"/*; do
        [[ -f "$f" ]] && sudo cp -p "$f" "$THEMES_DIR/$THEME/" && echo "kept $(basename "$f")"
    done
    sudo rm -rf "$keep"
    sudo chown -R root:root "$THEMES_DIR/$THEME"
    sudo chmod -R u=rwX,go=rX "$THEMES_DIR/$THEME"

    # The theme derives its colours from hypr-shell's accent (same maths as
    # the shell's palette.hpp), so the greeter matches the desktop. Take the
    # live value from the user's config, else the repo snapshot; theme.conf.user
    # overrides theme.conf without touching the vendored file. The same file
    # holds the "Login screen" page's settings (background, session menu,
    # default session) — only the accent key is touched here.
    msg "Matching hypr-shell's accent colour"
    accent=""
    for cfg in "/home/$USERNAME/.config/hypr-shell/config.json" "$REPO_DIR/config/hypr-shell/config.json"; do
        [[ -f "$cfg" ]] && command -v jq >/dev/null 2>&1 || continue
        accent=$(jq -r '.ui.accent // empty' "$cfg" 2>/dev/null) && [[ -n "$accent" ]] && break
    done
    local user_conf="$THEMES_DIR/$THEME/theme.conf.user"
    if [[ "$accent" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        # Replace-or-append: the file also carries the Login screen page's
        # settings (single [General] section), which must survive.
        if [[ -f "$user_conf" ]] && grep -q '^accent=' "$user_conf"; then
            sudo sed -i "s|^accent=.*|accent=$accent|" "$user_conf"
        elif [[ -f "$user_conf" ]]; then
            printf 'accent=%s\n' "$accent" | sudo tee -a "$user_conf" >/dev/null
        else
            printf '[General]\naccent=%s\n' "$accent" | sudo tee "$user_conf" >/dev/null
        fi
        echo "accent $accent (from $cfg)"
    else
        echo "no ui.accent found (jq missing or no config.json) — the theme's default applies"
    fi

    msg "Installing the $CURSOR_THEME cursor theme"
    if [[ -d "/usr/share/icons/$CURSOR_THEME" ]]; then
        echo "already installed"
    elif command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm --needed breezex-cursor-theme
    else
        echo "yay not found — install breezex-cursor-theme (AUR) by hand, the greeter falls back to the default cursor until then" >&2
    fi

    msg "Selecting $THEME and the $CURSOR_THEME cursor in $THEME_CONF"
    sudo mkdir -p "$CONF_DIR"
    # CursorTheme/CursorSize cover the root window (xsetroot) and the greeter;
    # GreeterEnvironment passes the same XCURSOR_* the desktop sets in
    # environment.lua straight to the greeter process as well.
    sudo tee "$THEME_CONF" >/dev/null <<EOF
[General]
GreeterEnvironment=XCURSOR_THEME=$CURSOR_THEME,XCURSOR_SIZE=$CURSOR_SIZE

[Theme]
Current=$THEME
CursorTheme=$CURSOR_THEME
CursorSize=$CURSOR_SIZE
EOF

    msg "Installing the SDDM avatar for $USERNAME"
    if [[ -f "$REPO_DIR/assets/profile.png" ]]; then
        sudo install -Dm644 "$REPO_DIR/assets/profile.png" "$FACES_DIR/$USERNAME.face.icon"
    else
        echo "$REPO_DIR/assets/profile.png not found — skipping"
    fi

    msg "Preselecting $USERNAME and the uwsm Hyprland session"
    if [[ -f "$STATE_FILE" ]]; then
        echo "$STATE_FILE exists — leaving SDDM's remembered choice alone"
    elif [[ ! -f "$UWSM_SESSION" ]]; then
        echo "$UWSM_SESSION not found (uwsm not installed?) — skipping"
    else
        sudo mkdir -p "$(dirname "$STATE_FILE")"
        sudo tee "$STATE_FILE" >/dev/null <<EOF
[Last]
Session=$UWSM_SESSION
User=$USERNAME
EOF
        if id sddm >/dev/null 2>&1; then
            sudo chown -R sddm:sddm "$(dirname "$STATE_FILE")"
        fi
    fi

    remove_direct_login

    msg "Enabling sddm.service"
    sudo systemctl enable sddm.service

    msg "Done — SDDM with the $THEME theme takes over from the next boot"
}

do_uninstall() {
    msg "Disabling sddm.service"
    sudo systemctl disable sddm.service 2>/dev/null || echo "not enabled"

    msg "Removing the theme, its config drop-in, the avatar and SDDM's state"
    sudo rm -rf "$THEMES_DIR/$THEME"
    sudo rm -f "$THEME_CONF" "$FACES_DIR/$USERNAME.face.icon" "$STATE_FILE"
    [[ -d "$CONF_DIR" ]] && sudo rmdir --ignore-fail-on-non-empty "$CONF_DIR"

    if pacman -Qq sddm >/dev/null 2>&1; then
        msg "Uninstalling sddm"
        sudo pacman -Rns --noconfirm sddm
    else
        echo "sddm is not installed"
    fi
    # Installed --asdeps above; drop it only if it is now an orphan.
    if pacman -Qtdq 2>/dev/null | grep -qx qt6-5compat; then
        msg "Uninstalling qt6-5compat (no longer needed)"
        sudo pacman -Rns --noconfirm qt6-5compat
    fi

    restore_direct_login

    msg "Done — direct login into Hyprland from the next boot"
}

do_status() {
    if pacman -Qq sddm >/dev/null 2>&1; then
        echo "sddm:      installed ($(pacman -Q sddm | awk '{print $2}')), service $(systemctl is-enabled sddm.service 2>/dev/null || echo '?')"
    else
        echo "sddm:      not installed"
    fi
    if [[ -d "$THEMES_DIR/$THEME" ]]; then
        echo "theme:     $THEME present in $THEMES_DIR"
    else
        echo "theme:     $THEME absent"
    fi
    if [[ -f "$THEME_CONF" ]]; then
        echo "config:    theme $(sed -nE 's/^Current=//p' "$THEME_CONF"), cursor $(sed -nE 's/^CursorTheme=//p' "$THEME_CONF") $(sed -nE 's/^CursorSize=//p' "$THEME_CONF") — $THEME_CONF"
    else
        echo "config:    no $THEME_CONF"
    fi
    if [[ -f "$FACES_DIR/$USERNAME.face.icon" ]]; then
        echo "avatar:    $FACES_DIR/$USERNAME.face.icon"
    else
        echo "avatar:    none"
    fi
    if [[ -f "$GETTY_OVERRIDE" ]]; then
        echo "autologin: tty1 override present"
    else
        echo "autologin: tty1 override absent"
    fi
    if has_profile_block; then
        echo "profile:   Hyprland autostart block present in $PROFILE"
    else
        echo "profile:   Hyprland autostart block absent from $PROFILE"
    fi
}

case "${1:-install}" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
    status)    do_status ;;
    *) echo "usage: $0 [install|uninstall|status]" >&2; exit 1 ;;
esac
