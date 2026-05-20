# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal Arch Linux dotfiles for a Hyprland + Quickshell desktop. There is no build step and no test suite — the "deliverable" is the contents of `~/.config`, `~/.local`, and a few system paths (udev rules, fonts, icons, sounds, `.desktop` overrides). Everything is wired together by [install.sh](install.sh).

## Installing / re-applying

[install.sh](install.sh) is the only entry point. It is **destructive** — line 101 runs `rm -rf /home/$USERNAME/.config/*` before copying — so never run it on a machine you haven't already backed up.

It expects Arch with `pacman` and `yay`, and assumes it's run via `sudo` (it uses `logname` to discover the real user). Typical usage:

```
./install.sh
```

What it does, in order: installs Hyprland/Quickshell/etc. packages, installs two AUR packages via `yay`, copies the udev rules from [assets/](assets/) into `/etc/udev/rules.d/` (substituting `$USERNAME`), copies sound + font assets into `/usr/share/`, installs `.desktop` overrides, **wipes and replaces** `~/.config/*` from [config/](config/), copies [local/](local/) into `~/.local/`, sets up tty1 autologin + a `.zprofile` that `exec uwsm start hyprland.desktop`, patches the user's name into [config/hypr/hyprlock.conf](config/hypr/hyprlock.conf), sets gsettings + xdg-mime defaults, then reboots.

Reload Hyprland config in a running session with `Super+Shift+N` (bound to `hyprctl reload`). The Quickshell config can be reloaded by killing/relaunching `qs`.

## Top-level layout

- [assets/](assets/) — files that get copied to **system** locations during install. Udev rules, fonts, sounds, app icons, `.desktop` overrides, and a `nautilus` dconf dump.
- [config/](config/) — copied verbatim to `~/.config/`. The bulk of the repo.
- [local/](local/) — copied verbatim to `~/.local/`. Currently just [bin/power-mode](local/bin/power-mode).
- [docs/](docs/) — loose notes (e.g. [secureboot.txt](docs/secureboot.txt) for `sbctl` enrollment).

## Hyprland config

[config/hypr/hyprland.conf](config/hypr/hyprland.conf) is intentionally tiny — it just sets the monitor and `source =`s every file in [config/hypr/conf/](config/hypr/conf/) (`animations`, `autostart`, `environment`, `keybinds`, `layout`, `windowrules`). To change behavior, edit the file in `conf/`, not the top-level `hyprland.conf`.

[autostart.conf](config/hypr/conf/autostart.conf) launches `qs` (Quickshell) — the shell, bar, notifications, and all popup panels come from there, not from Hyprland.

Media/brightness keys, screenshot bindings (`grim`/`slurp`/`wl-copy`), and the panel toggles (`qs ipc call <target> toggle`) all live in [keybinds.conf](config/hypr/conf/keybinds.conf).

## Quickshell shell (the UI layer)

[config/quickshell/shell.qml](config/quickshell/shell.qml) is the root. It instantiates **one** of each panel/overlay (`StartMenu`, `Launcher`, `Calendar`, `Clipboard`, the four `*QuickSettings` flyouts, `Tooltip`, `PinnedContextMenu`, and the `Bar` itself) plus two background services (`PinnedApps`, `Notifications`). Panels are opened by flipping their `open` property — they aren't created on demand.

Two patterns matter when adding to the shell:

1. **IPC toggles.** Hyprland keybinds invoke panels via `qs ipc call <target> toggle`. Each toggleable panel needs a matching `IpcHandler { target: "<name>"; function toggle() { ... } }` block in `shell.qml`. Existing examples: `launcher`, `startmenu`, `clipboard`, `bluetoothqs`.
2. **Mutually-exclusive flyouts.** Only one quick-settings flyout (battery/audio/network/bluetooth) can be open at a time. `shell.qml`'s `closeOtherQS(keep)` enforces this; any new flyout in that family must be routed through it.

### Services

- [services/PinnedApps.qml](config/quickshell/services/PinnedApps.qml) — holds the centered taskbar's pinned desktop-entry IDs and persists them to `~/.config/quickshell/pinned.json` via `sh -c "mkdir -p ... && printf ..."` through `Quickshell.Io.Process`. Reads via the same mechanism on `Component.onCompleted`. If you change the persistence format, update both `save()` and the loader.
- [services/Notifications.qml](config/quickshell/services/Notifications.qml) — registers as the `org.freedesktop.Notifications` DBus daemon (replaces dunst). Holds the popup queue (`maxPopups = 5`, critical never expires); the actual rendering is in [modules/notifications/NotificationPopup.qml](config/quickshell/modules/notifications/NotificationPopup.qml), which binds to `service.popups`.

### Modules

Each subdir of [modules/](config/quickshell/modules/) is one panel + its components: `bar/`, `startmenu/`, `launcher/`, `calendar/`, `clipboard/`, `notifications/`, `quicksettings/`. The panel's top-level QML file matches the dir name (`Bar.qml`, `StartMenu.qml`, …) and is imported by `shell.qml`.

### Styling

All colors, radii, and the bar height come from the singleton in [styles/Theme.qml](config/quickshell/styles/Theme.qml) (registered via [styles/qmldir](config/quickshell/styles/qmldir)). To restyle the shell, edit the singleton — don't hardcode colors in components. Import with `import "../../styles"` (path depth depends on where the component lives) and use as `Theme.barBg`, `Theme.menuRadius`, etc.

### Bar architecture

[modules/bar/Bar.qml](config/quickshell/modules/bar/Bar.qml) is a `PanelWindow` anchored to the bottom edge with `WlrLayershell.exclusiveZone = Theme.barHeight` so maximized windows don't draw under it. Layout is left (StartButton + SearchButton + Workspaces), center (`PinnedBar`), right (Clipboard / Network / Battery / Volume / Clock).

Indicators don't own their flyouts — they emit signals (`toggleBatteryQS`, etc.) that `shell.qml` routes through `closeOtherQS()`. There is also an **optimistic** path: `BatteryQuickSettings.profileChanged` → `Bar.setPowerProfile()` so the battery glyph swaps to the BatterySaver family immediately instead of waiting for the indicator's 10-second poll.

## Power profiles

[local/bin/power-mode](local/bin/power-mode) bundles `powerprofilesctl` + a monitor refresh-rate change + a notification. It's the single source of truth for "power saver = 60 Hz, balanced/performance = 144 Hz" — change refresh rates here, not in `hyprland.conf`.

Automatic switching on AC plug/unplug is driven by udev (`assets/99-power.rules`) firing the `acpoweron.service` / `acpoweroff.service` systemd user units in [config/systemd/user/](config/systemd/user/). USB insert/remove notifications work the same way (`assets/90-usb.rules` → `usb-insert.service` / `usb-remove.service`).

Note that the udev rules contain a literal `USERNAME` token that [install.sh](install.sh) `sed`s into the real user during install — when editing those rules in the repo, leave the token as `USERNAME`.
