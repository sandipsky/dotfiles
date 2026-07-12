# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal Arch Linux dotfiles for a Hyprland + Noctalia desktop. There is no build step and no test suite — the "deliverable" is the contents of `~/.config`, `~/.local`, and a few system paths (udev rules, fonts, icons, `.desktop` overrides). Everything is wired together by [install.sh](install.sh).

## Installing / re-applying

[install.sh](install.sh) is the main entry point, and it targets a **fresh Arch install** — it never uninstalls packages or cleans up prior setups, so don't add migration logic to it. It's still destructive in places (overlays files into `~/.config/`, edits `/etc/sudoers` and `/etc/systemd/system/`, ends with `reboot`) — never run it on a machine you haven't already backed up.

It expects Arch with `pacman` and `yay`, and assumes it's run via `sudo` (it uses `logname` to discover the real user). Typical usage:

```
./install.sh
```

[noctalia.sh](noctalia.sh) is a mirror of install.sh that installs the **original** upstream Noctalia instead of the fork: it adds the AUR `noctalia-shell` package (which lands in `/etc/xdg/quickshell/` and pulls `noctalia-qs` itself, so the local-build fallback is omitted) and deletes `~/.config/quickshell/noctalia-shell` after the config copy so Quickshell falls through to the stock version. Everything else is identical — when editing install.sh, mirror the change here.

[reset.sh](reset.sh) is the day-to-day helper for the vendored Noctalia fork: run it **as your user** (unlike install.sh) with `./reset.sh`. It removes the AUR `noctalia-shell` package if still present (the only step that sudo-prompts, keeping the `noctalia-qs` runtime installed), syncs [config/quickshell/noctalia-shell/](config/quickshell/) to `~/.config/quickshell/noctalia-shell/` (full replace, so deleted files don't linger), and cleanly restarts the shell. It never touches `~/.config/noctalia/settings.json`, so runtime settings survive.

What it does, in order: sets up DNS first so the rest of the install isn't throttled (the GLX router's first DHCP DNS server, 110.44.112.200, is dead and glibc stalls 5 s per lookup on it — the script pins working resolvers on the `GLX` Wi-Fi profile when present, enables systemd-resolved with the stub-resolv.conf symlink, and restarts NetworkManager), installs Hyprland/etc. packages, installs AUR packages via `yay`, installs `noctalia-qs` (tries AUR first, falls back to building the vendored recipe in [assets/noctalia-qs/](assets/)) — a pinned Quickshell fork that conflicts with the official `quickshell` package, so never add `quickshell` to the pacman list; Noctalia itself is **not** installed from AUR, its source is vendored in this repo (see below) — copies the udev rules from [assets/](assets/) into `/etc/udev/rules.d/` (substituting `$USERNAME`), copies font assets into `/usr/share/fonts`, installs `.desktop` overrides into the user's `~/.local/share/applications/`, copies [config/](config/) into the user's `~/.config/`, substitutes `USERNAME` into [config/noctalia/settings.json](config/noctalia/settings.json), seeds the user's avatar at `~/.face` from [assets/profile.png](assets/profile.png), sets up tty1 autologin + a `.zprofile` that `exec uwsm start hyprland.desktop`, sets gsettings + xdg-mime defaults, runs `xdg-user-dirs-update`, then reboots.

### Root vs. user pattern

The script is invoked under `sudo`, so by default every command runs as root. Anything that writes to system paths (`/etc`, `/usr/share`, `pacman`) is fine as-is. Anything that touches the user's home or per-user config must drop privileges with `sudo -u "$USERNAME"` — otherwise the writes go to `/root` (or root's dconf) and the user can't read/modify them. The pattern in the script:

- `sudo -u "$USERNAME" cp …` for files under `/home/$USERNAME/.config/` and `/home/$USERNAME/.local/`
- `sudo -u "$USERNAME" -H dbus-run-session -- …` for `dconf load` and `gsettings set` (needs a session bus)
- `sudo -u "$USERNAME" -H xdg-mime …` / `xdg-user-dirs-update` (need `$HOME`)
- `yay` is also non-root by design — leave it without a `sudo` prefix

When adding to `install.sh`, decide which side of this split your command belongs on. Never use `~` or `$HOME` — they expand to `/root` here; use `/home/$USERNAME/…` explicitly.

Reload Hyprland config in a running session with `Super+Shift+N` (bound to `hyprctl reload`). Restart Noctalia by killing `qs` and relaunching `qs -c noctalia-shell`.

## Top-level layout

- [assets/](assets/) — files that get copied to **system** locations during install (udev rules, fonts, app icons, `.desktop` overrides, a `nautilus` dconf dump), plus `profile.png`, which becomes the user's `~/.face` avatar. Also `noctalia-qs/` — a vendored copy of the AUR PKGBUILD and source tarball for the Quickshell runtime; install.sh tries AUR first and falls back to building this local copy if the download fails (so the setup reproduces without AUR/GitHub); refresh both files together when bumping the runtime version.
- [config/](config/) — copied verbatim to `~/.config/` (`alacritty`, `gtk-3.0`, `hypr`, `noctalia`, `quickshell`, `systemd/user`). The bulk of the repo; `quickshell/noctalia-shell/` is the vendored Noctalia source tree.
- [docs/](docs/) — loose notes (e.g. [secureboot.txt](docs/secureboot.txt) for `sbctl` enrollment).

## Hyprland config

[config/hypr/hyprland.conf](config/hypr/hyprland.conf) is intentionally tiny — it just sets the monitor and `source =`s every file in [config/hypr/conf/](config/hypr/conf/) (`animations`, `autostart`, `environment`, `keybinds`, `layout`, `windowrules`). To change behavior, edit the file in `conf/`, not the top-level `hyprland.conf`.

[autostart.conf](config/hypr/conf/autostart.conf) launches only the polkit agent and `qs -c noctalia-shell` — there are deliberately no idle/night-light/wallpaper/clipboard daemons there, because Noctalia owns all of those (see below).

Media/brightness keys, screenshot bindings (`grim`/`slurp`/`wl-copy`), and all Noctalia panel/action bindings live in [keybinds.conf](config/hypr/conf/keybinds.conf).

## Noctalia (the UI layer)

The shell is [Noctalia](https://github.com/noctalia-dev/noctalia) **v4** (the Quickshell-based line). Its full source is vendored at [config/quickshell/noctalia-shell/](config/quickshell/) — a snapshot of the upstream tree (currently v4.7.7) carrying local UI/behavior patches on top — so the config copy installs it to `~/.config/quickshell/noctalia-shell/`, where it's launched with `qs -c noctalia-shell`. Quickshell searches `~/.config/quickshell/` before `/etc/xdg/quickshell/`, so this shadows any leftover copy from the old AUR `noctalia-shell` package. The `noctalia-qs` runtime installs from AUR when available, falling back to a build of the vendored copy in [assets/noctalia-qs/](assets/) — so the setup reproduces even without upstream's GitHub; Noctalia's other runtime deps (`imagemagick`, `ffmpeg`, `qt6-multimedia`, `python`, `wlr-randr`) are listed explicitly in install.sh's pacman list — keep those in sync with upstream's PKGBUILD `depends` when bumping the vendored version. It provides the bar (top) + auto-hide dock, launcher (app search / clipboard history / calculator / emoji), control center, notification daemon (`org.freedesktop.Notifications`), session menu, PAM lock screen, idle management (ext-idle-notify), night light (via `wlsunset`), wallpaper management, and volume/brightness OSDs — which is why this repo has no hyprlock/hypridle/hyprsunset/wpaperd/dunst configs.

Points that matter when changing things:

- **Vendored source.** Edit UI/behavior directly in [config/quickshell/noctalia-shell/](config/quickshell/); local patches are just git diffs against the vendored upstream snapshot. To see a change live, run [reset.sh](reset.sh) (syncs the tree to `~/.config/quickshell/noctalia-shell/` and restarts the shell); for rapid iteration, edit `~/.config/quickshell/noctalia-shell/` directly instead — Quickshell hot-reloads on file change — then copy the result back into the repo. To bump upstream: clone the new tag, overlay it onto the vendored dir (`rsync -a --delete`, keeping only `.git`-less content like the AUR package's `cp -r ./*` did), review `git diff` to re-apply local patches, and sync install.sh's dep list with the new PKGBUILD.
- **Settings.** [config/noctalia/settings.json](config/noctalia/settings.json) is a snapshot of the machine's `~/.config/noctalia/settings.json` (Noctalia deep-merges it over its built-in defaults). It contains `/home/USERNAME/...` paths with a literal `USERNAME` token that install.sh `sed`s at install time — keep the token in the repo copy. The Settings GUI on the machine rewrites the live file at runtime; those changes don't flow back into the repo (re-running install.sh overwrites them), so refresh the snapshot with `sed 's|/home/<user>|/home/USERNAME|g' ~/.config/noctalia/settings.json > config/noctalia/settings.json` when the current setup should become the installed default.
- **IPC.** Keybinds call `qs -c noctalia-shell ipc call <target> <function>` via the `$noctalia` variable in keybinds.conf. Targets currently bound: `launcher` (toggle / clipboard), `controlCenter toggle` (Super+A), `sessionMenu` (toggle on Super+X, `lockAndSuspend` on lid close), `lockScreen lock` (Super+L / XF86Lock), `wallpaper` (toggle on Super+Shift+W, random on Super+P), `volume` and `brightness` (media keys, so Noctalia's OSD shows). Run `qs -c noctalia-shell ipc show` on the machine to list every available target.
- **Idle/lock.** Idle behavior lives in settings.json: lock at 600 s, screen off at 660 s, suspend at 3600 s, lock-before-suspend enabled. There is no media-playback exemption — use Noctalia's Keep-Awake toggle (control center / `idleInhibitor` IPC) when watching video.
- **Clipboard.** Noctalia spawns its own `wl-paste` → `cliphist` watchers (text *and* images) because `appLauncher.enableClipboardHistory` is true — do not add a cliphist watcher back to autostart.conf.
- **Theming.** Colors are generated from the current wallpaper (`colorSchemes.useWallpaperColors`, dark mode); wallpapers are read from `~/Pictures/Wallpapers`. Switch to a fixed scheme in Settings → Color scheme if ever needed.

## Power profiles

Automatic switching on AC plug/unplug is driven by udev (`assets/99-power.rules`) firing the `acpoweron.service` / `acpoweroff.service` systemd user units in [config/systemd/user/](config/systemd/user/), which call `powerprofilesctl set performance` / `set power-saver` directly (`power-profiles-daemon` is in the package list; Noctalia's battery widget reads/sets the same profiles). The `usb-insert.service` / `usb-remove.service` units play a sound via `paplay` when triggered.

Note that the udev rules contain a literal `USERNAME` token that [install.sh](install.sh) `sed`s into the real user during install — same pattern as `config/noctalia/settings.json`; when editing these files in the repo, leave the token as `USERNAME`.
