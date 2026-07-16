#!/bin/bash
# Migrate this machine from the vendored Noctalia v4 fork (Quickshell/QML) to
# the Noctalia v5 beta (the C++ rewrite), packaged on the AUR as `noctalia`
# (currently 5.0.0_beta2).
#
# Run as your normal user: ./noctalia5.sh   (sudo-prompts only for pacman)
#
# What it does:
#   1. Installs the `noctalia` AUR package (v5 beta) FIRST, so the machine is
#      never left without a shell if the install fails.
#   2. Rewrites the LIVE Hyprland config (~/.config/hypr/conf/) to launch v5
#      and use the new `noctalia msg` IPC (backups kept as *.v4bak).
#   3. Stops the running v4 shell and removes it: the vendored fork in
#      ~/.config/quickshell/noctalia-shell, the AUR `noctalia-shell` package
#      (if present), and the `noctalia-qs` Quickshell runtime.
#   4. Reloads Hyprland and starts v5.
#
# What it does NOT touch:
#   - The repo itself. config/hypr, config/quickshell and install.sh still
#     carry v4 — if you keep v5, port the keybind/autostart changes into the
#     repo before the next install.sh run, or it will resurrect v4 configs.
#   - ~/.config/noctalia/settings.json (v4 settings). v5 reads TOML
#     (~/.config/noctalia/*.toml + ~/.local/state/noctalia/settings.toml) and
#     ignores the JSON; there is no upstream migration path, so v5 starts with
#     defaults and you reconfigure via its settings UI.
#
# Rollback: ./reset.sh, then restore the *.v4bak files in ~/.config/hypr/conf/
# and `hyprctl reload`. Optionally `sudo pacman -R noctalia`.

set -e

if [[ $EUID -eq 0 ]]; then
    echo "Run noctalia5.sh as your normal user, not with sudo." >&2
    exit 1
fi

HYPR_CONF="$HOME/.config/hypr/conf"

# --- 1. Install Noctalia v5 beta ---------------------------------------------
# `noctalia` is the release-pinned AUR package (5.0.0_beta2 as of 2026-07);
# `noctalia-git` would track main instead of the beta tags.
if ! pacman -Qq noctalia >/dev/null 2>&1; then
    yay -S --noconfirm --needed noctalia
fi

if ! command -v noctalia >/dev/null 2>&1; then
    echo "noctalia binary not found after install - aborting before touching v4." >&2
    exit 1
fi

# --- 2. Rewire the live Hyprland config to v5 --------------------------------
if [[ -f "$HYPR_CONF/autostart.conf" ]]; then
    [[ -f "$HYPR_CONF/autostart.conf.v4bak" ]] || cp "$HYPR_CONF/autostart.conf" "$HYPR_CONF/autostart.conf.v4bak"
    sed -i 's|^exec-once = qs -c noctalia-shell$|exec-once = noctalia|' "$HYPR_CONF/autostart.conf"
fi

if [[ -f "$HYPR_CONF/keybinds.conf" ]]; then
    [[ -f "$HYPR_CONF/keybinds.conf.v4bak" ]] || cp "$HYPR_CONF/keybinds.conf" "$HYPR_CONF/keybinds.conf.v4bak"
    sed -i \
        -e 's|= qs -c noctalia-shell ipc call|= noctalia msg|' \
        -e 's|\$noctalia launcher toggle|\$noctalia panel-toggle launcher|g' \
        -e 's|\$noctalia launcher clipboard|\$noctalia panel-toggle clipboard|g' \
        -e 's|\$noctalia controlCenter toggle|\$noctalia panel-toggle control-center|g' \
        -e 's|\$noctalia sessionMenu toggle|\$noctalia panel-toggle session|g' \
        -e 's|\$noctalia sessionMenu lockAndSuspend|\$noctalia session lock-and-suspend|g' \
        -e 's|\$noctalia lockScreen lock|\$noctalia session lock|g' \
        -e 's|\$noctalia wallpaper toggle|\$noctalia panel-toggle wallpaper|g' \
        -e 's|\$noctalia wallpaper random|\$noctalia wallpaper-random|g' \
        -e 's|\$noctalia brightness increase|\$noctalia brightness-up|g' \
        -e 's|\$noctalia brightness decrease|\$noctalia brightness-down|g' \
        -e 's|\$noctalia volume increase|\$noctalia volume-up|g' \
        -e 's|\$noctalia volume decrease|\$noctalia volume-down|g' \
        -e 's|\$noctalia volume muteOutput|\$noctalia volume-mute|g' \
        -e 's|\$noctalia volume muteInput|\$noctalia mic-mute|g' \
        "$HYPR_CONF/keybinds.conf"
fi

# --- 3. Stop and remove Noctalia v4 -------------------------------------------
pkill -f '(^|/)qs -c noctalia-shell' || true
for _ in $(seq 1 20); do
    pgrep -f '(^|/)qs -c noctalia-shell' >/dev/null || break
    sleep 0.2
done
# v4 spawned its own clipboard watchers; v5 brings its own clipboard manager
pkill -f 'wl-paste.*cliphist' || true

# The vendored v4 fork
rm -rf "$HOME/.config/quickshell/noctalia-shell"

# AUR v4 packages: noctalia-shell depends on noctalia-qs, so remove it first
if pacman -Qq noctalia-shell >/dev/null 2>&1; then
    sudo pacman -R --noconfirm noctalia-shell
fi
if pacman -Qq noctalia-qs >/dev/null 2>&1; then
    sudo pacman -R --noconfirm noctalia-qs
fi

# --- 4. Reload Hyprland and start v5 ------------------------------------------
if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null
    hyprctl dispatch exec noctalia >/dev/null
else
    # Not inside a Hyprland session (e.g. tty) - start detached as a fallback
    setsid noctalia >/dev/null 2>&1 < /dev/null &
fi

sleep 2
if pgrep -x noctalia >/dev/null; then
    echo "Noctalia v5 ($(pacman -Q noctalia | awk '{print $2}')) is running; v4 fork removed."
    echo "Settings did not migrate - configure via the v5 settings UI or ~/.config/noctalia/*.toml."
    echo "Reminder: the repo still carries v4; port the hypr config changes before re-running install.sh."
else
    echo "Noctalia v5 did not start - run 'noctalia' in a terminal to see errors." >&2
    echo "Rollback: ./reset.sh, restore $HYPR_CONF/*.v4bak, then 'hyprctl reload'." >&2
    exit 1
fi
