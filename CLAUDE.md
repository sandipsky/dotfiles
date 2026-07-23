# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal Arch Linux dotfiles for a Hyprland + Noctalia desktop. There is no build step and no test suite — the "deliverable" is the contents of `~/.config`, `~/.local`, and a few system paths (udev rules, fonts, icons, `.desktop` overrides). Everything is wired together by [install.sh](install.sh).

## Installing / re-applying

[install.sh](install.sh) is the main entry point, and it targets a **fresh Arch install** — it never uninstalls packages or cleans up prior setups, so don't add migration logic to it. It's still destructive in places (overlays files into `~/.config/`, edits `/etc/sudoers` and `/etc/systemd/system/`, ends with `reboot`) — never run it on a machine you haven't already backed up.

It expects Arch with `pacman` and `yay`, and is run as the **normal user** — it refuses to start as root (`yay`/`makepkg` won't build as root), asks for the sudo password once up front (`sudo -v`), and a background keepalive refreshes the sudo timestamp for the whole run so long builds never stall on a mid-run re-prompt (`logname` discovers the user). Typical usage:

```
./install.sh
```

This repo installs only the vendored Noctalia **fork** — there are no alternate-variant install scripts anymore (the old `noctalia.sh` for original upstream and the v4↔v5 switchers were removed). Manual steps for running original upstream Noctalia instead of the fork are kept for reference in [docs/original-noctalia.txt](docs/original-noctalia.txt) (note: it references the removed `noctalia.sh`; only its manual `~/.config`-level steps still apply).

[rebuild-nautilus.sh](rebuild-nautilus.sh) is the day-to-day helper for the vendored Nautilus fork (see "Nautilus (file manager fork)" below): run it **as your user** with `./rebuild-nautilus.sh` after editing the source — it builds the package from [applications/nautilus-fork/](applications/nautilus-fork/) and installs it. It's DE-safe by design: the fork replaces the official `nautilus` package in place (same name), the `pacman -U` step is deliberately interactive so any proposed conflict removals must be confirmed, and it refuses to silently downgrade if the installed nautilus is newer than the fork (prompts; the right fix is bumping the vendored tree).

[reset.sh](reset.sh) is the day-to-day helper for the vendored Noctalia fork: run it **as your user** with `./reset.sh`. It removes the AUR `noctalia-shell` package if still present and rebuilds `noctalia-qs` from [applications/noctalia-qs/](applications/) if it's missing (both steps sudo-prompt but are normally skipped), syncs [config/quickshell/noctalia-shell/](config/quickshell/) to `~/.config/quickshell/noctalia-shell/` (full replace, so deleted files don't linger), and cleanly restarts the shell. It never touches `~/.config/noctalia/settings.json`, so runtime settings survive.

What it does, in order: sets up DNS first so the rest of the install isn't throttled (the GLX router's first DHCP DNS server, 110.44.112.200, is dead and glibc stalls 5 s per lookup on it — the script pins working resolvers on the `GLX` Wi-Fi profile when present, enables systemd-resolved with the stub-resolv.conf symlink, and restarts NetworkManager), installs Hyprland/etc. packages, installs AUR packages via `yay`, builds and installs `noctalia-qs` from the vendored recipe in [applications/noctalia-qs/](applications/) (never from AUR — upstream discontinued the fork when Noctalia v5 dropped Quickshell, so the AUR package is unmaintained and untrusted for `--noconfirm` builds) — a pinned Quickshell fork that conflicts with the official `quickshell` package, so never add `quickshell` to the pacman list; Noctalia itself is **not** installed from AUR, its source is vendored in this repo (see below) — builds and installs the Nautilus fork from [applications/nautilus-fork/](applications/nautilus-fork/) (the official `nautilus` package is never installed — `pacman -U` resolves the fork's runtime deps itself) and adds `IgnorePkg = nautilus libnautilus-extension` to `/etc/pacman.conf` — copies the udev rules from [assets/](assets/) into `/etc/udev/rules.d/` (substituting `$USERNAME`), installs `assets/bin/extract-audio` to `/usr/local/bin` (extracts video audio tracks as MP3 — DaVinci Resolve on Linux can't decode AAC; canonical copy also lives at `~/resolve/extract-audio.sh`, whose resolve-restore.sh skips installing its own if this one is on PATH), copies font assets into `/usr/share/fonts`, installs `.desktop` overrides into the user's `~/.local/share/applications/`, copies [config/](config/) into the user's `~/.config/`, substitutes `USERNAME` into [config/noctalia/settings.json](config/noctalia/settings.json), seeds the user's avatar at `~/.face` from [assets/profile.png](assets/profile.png), sets up tty1 autologin + a `.zprofile` that `exec uwsm start hyprland.desktop`, sets gsettings + xdg-mime defaults, runs `xdg-user-dirs-update`, then reboots.

### Root vs. user pattern

The script runs as the normal user, never as root — it exits early if `$EUID` is 0, because `yay` and `makepkg` refuse to build as root. It authenticates sudo once at the top (`sudo -v`) and a background keepalive (killed by a `trap … EXIT`) refreshes the credential cache every 60 s, so the long pacman/yay/makepkg steps never stop midway to re-prompt — this also covers the `sudo` calls that yay/makepkg make internally, since they share the same tty timestamp. The split when adding commands:

- System paths (`/etc`, `/usr/share`, `/usr/local`, `pacman -S`/`-U`, `systemctl`) — prefix with `sudo`.
- The user's home, `yay`, `makepkg`, `xdg-mime`, `xdg-user-dirs-update` — run plainly as the user. Many of these lines still carry a `sudo -u "$USERNAME"` prefix from the script's older run-as-root layout; that's now a harmless no-op (sudo to yourself), fine to keep or drop when touching a line.
- `dconf load` / `gsettings set` keep the `dbus-run-session --` wrapper — on a fresh install the script runs from a bare tty with no session bus.

The script consistently uses `/home/$USERNAME/…` rather than `~`/`$HOME` (a holdover from the run-as-root layout that also keeps paths unambiguous inside `sudo` heredocs) — keep doing that.

Reload Hyprland config in a running session with `Super+Shift+N` (bound to `hyprctl reload`). Restart Noctalia by killing `qs` and relaunching `qs -c noctalia-shell`.

## Top-level layout

- [applications/](applications/) — vendored applications built/installed from the repo. `noctalia-qs/` — a PKGBUILD and source tarball for the Quickshell runtime; install.sh and reset.sh build **only** this local copy (AUR is deliberately not used: upstream discontinued the fork at 0.0.12, its final version, so the setup reproduces without AUR/GitHub and can't be affected by the abandoned AUR package changing hands). `nautilus-fork/` — a PKGBUILD plus the full vendored Nautilus source tree (see "Nautilus (file manager fork)" below). `music/` — a meson-built music app whose own install.sh installs it to `~/.local`.
- [assets/](assets/) — files that get copied to **system** locations during install (udev rules, fonts, app icons, `.desktop` overrides, a `nautilus` dconf dump), plus `profile.png`, which becomes the user's `~/.face` avatar.
- [config/](config/) — copied verbatim to `~/.config/` (`alacritty`, `gtk-3.0`, `hypr`, `noctalia`, `quickshell`, `systemd/user`). The bulk of the repo; `quickshell/noctalia-shell/` is the vendored Noctalia source tree.
- [docs/](docs/) — loose notes (e.g. [secureboot.txt](docs/secureboot.txt) for `sbctl` enrollment). [noctalia-patches.md](docs/noctalia-patches.md) documents every local patch carried on the vendored Noctalia fork, feature by feature — keep it updated when patching the fork, so the customizations can be re-applied on a future upstream rewrite. [nautilus-patches.md](docs/nautilus-patches.md) does the same for the vendored Nautilus fork.

## Hyprland config

[config/hypr/hyprland.conf](config/hypr/hyprland.conf) is intentionally tiny — it just sets the monitor and `source =`s every file in [config/hypr/conf/](config/hypr/conf/) (`animations`, `autostart`, `environment`, `keybinds`, `layout`, `windowrules`). To change behavior, edit the file in `conf/`, not the top-level `hyprland.conf`.

[autostart.conf](config/hypr/conf/autostart.conf) launches only the polkit agent and `qs -c noctalia-shell` — there are deliberately no idle/night-light/wallpaper/clipboard daemons there, because Noctalia owns all of those (see below).

Media/brightness keys, screenshot bindings (`grim`/`slurp`/`wl-copy`), and all Noctalia panel/action bindings live in [keybinds.conf](config/hypr/conf/keybinds.conf).

## Noctalia (the UI layer)

The shell is [Noctalia](https://github.com/noctalia-dev/noctalia) **v4** (the Quickshell-based line). Its full source is vendored at [config/quickshell/noctalia-shell/](config/quickshell/) — a snapshot of the upstream tree (currently v4.7.7) carrying local UI/behavior patches on top — so the config copy installs it to `~/.config/quickshell/noctalia-shell/`, where it's launched with `qs -c noctalia-shell`. Quickshell searches `~/.config/quickshell/` before `/etc/xdg/quickshell/`, so this shadows any leftover copy from the old AUR `noctalia-shell` package. The `noctalia-qs` runtime is built from the vendored copy in [applications/noctalia-qs/](applications/) only (AUR is not used — the fork is discontinued upstream, 0.0.12 is final); Noctalia's other runtime deps (`imagemagick`, `ffmpeg`, `qt6-multimedia`, `python`, `wlr-randr`) are listed explicitly in install.sh's pacman list. It provides the bar (top) + auto-hide dock, launcher (app search / clipboard history / calculator / emoji), control center, notification daemon (`org.freedesktop.Notifications`), session menu, PAM lock screen, idle management (ext-idle-notify), night light (via `wlsunset`), wallpaper management, and volume/brightness OSDs — which is why this repo has no hyprlock/hypridle/hyprsunset/wpaperd/dunst configs.

Points that matter when changing things:

- **Vendored source.** Edit UI/behavior directly in [config/quickshell/noctalia-shell/](config/quickshell/); local patches are just git diffs against the vendored upstream snapshot. To see a change live, run [reset.sh](reset.sh) (syncs the tree to `~/.config/quickshell/noctalia-shell/` and restarts the shell); for rapid iteration, edit `~/.config/quickshell/noctalia-shell/` directly instead — Quickshell hot-reloads on file change — then copy the result back into the repo. To bump upstream: clone the new tag, overlay it onto the vendored dir (`rsync -a --delete`, keeping only `.git`-less content like the AUR package's `cp -r ./*` did), review `git diff` to re-apply local patches, and sync install.sh's dep list with the new PKGBUILD.
- **Settings.** [config/noctalia/settings.json](config/noctalia/settings.json) is a snapshot of the machine's `~/.config/noctalia/settings.json` (Noctalia deep-merges it over its built-in defaults). It contains `/home/USERNAME/...` paths with a literal `USERNAME` token that install.sh `sed`s at install time — keep the token in the repo copy. The Settings GUI on the machine rewrites the live file at runtime; those changes don't flow back into the repo (re-running install.sh overwrites them), so refresh the snapshot with `sed 's|/home/<user>|/home/USERNAME|g' ~/.config/noctalia/settings.json > config/noctalia/settings.json` when the current setup should become the installed default.
- **IPC.** Keybinds call `qs -c noctalia-shell ipc call <target> <function>` via the `$noctalia` variable in keybinds.conf. Targets currently bound: `launcher` (toggle / clipboard), `controlCenter toggle` (Super+A), `sessionMenu` (toggle on Super+X, `lockAndSuspend` on lid close), `lockScreen lock` (Super+L / XF86Lock), `wallpaper` (toggle on Super+Shift+W, random on Super+P), `volume` and `brightness` (media keys, so Noctalia's OSD shows). Run `qs -c noctalia-shell ipc show` on the machine to list every available target.
- **Idle/lock.** Idle behavior lives in settings.json: lock at 600 s, screen off at 660 s, suspend at 3600 s, lock-before-suspend enabled. There is no media-playback exemption — use Noctalia's Keep-Awake toggle (control center / `idleInhibitor` IPC) when watching video.
- **Clipboard.** Noctalia spawns its own `wl-paste` → `cliphist` watchers (text *and* images) because `appLauncher.enableClipboardHistory` is true — do not add a cliphist watcher back to autostart.conf.
- **Theming.** Colors are generated from the current wallpaper (`colorSchemes.useWallpaperColors`, dark mode); wallpapers are read from `~/Pictures/Wallpapers`. Switch to a fixed scheme in Settings → Color scheme if ever needed.

## Nautilus (file manager fork)

The file manager is a local fork of GNOME Nautilus. The full upstream source (50.2.2, matching the Arch package it replaces) is vendored at [applications/nautilus-fork/nautilus/](applications/nautilus-fork/), with local feature patches carried directly on that tree as git diffs — same convention as the Noctalia fork. [applications/nautilus-fork/PKGBUILD](applications/nautilus-fork/PKGBUILD) (adapted from Arch's official one; docs subpackage and test suite dropped) builds `nautilus` + `libnautilus-extension` **only** from the vendored tree — fully offline, nothing fetched from repos/AUR/git.

Points that matter when changing things:

- **Workflow.** Edit the C/blueprint source in `applications/nautilus-fork/nautilus/`, then run [rebuild-nautilus.sh](rebuild-nautilus.sh) as your user — it copies the recipe to a temp dir, `makepkg -s`, installs both packages with `pacman -U`, and quits the running Nautilus instance so the next launch picks up the new binary. Unlike Noctalia there is no hot reload — every change is a full compile (a few minutes).
- **Versioning.** The fork is `50.2.2-1.1` — a pkgrel bump over the repo's `-1` so `pacman -U` supersedes it. Both install.sh and rebuild-nautilus.sh ensure `IgnorePkg = nautilus libnautilus-extension` in `/etc/pacman.conf` so `-Syu` never replaces the fork; upgrades happen only by bumping the vendored tree. The official `nautilus` is deliberately absent from install.sh's pacman list — the fork's PKGBUILD declares all runtime deps and `pacman -U` resolves them from the repos. To return to stock: remove the IgnorePkg line, `sudo pacman -S nautilus libnautilus-extension`.
- **Patch log.** Document every feature patch in [docs/nautilus-patches.md](docs/nautilus-patches.md) (by behavior, not diff) so it can be re-applied when bumping upstream. That file also records the upstream baseline commit and the bump procedure.
- **No third-party menu extensions.** "Open in Terminal" (alacritty/kitty) and "Open in Code" are patched directly into the fork's context menus (see [docs/nautilus-patches.md](docs/nautilus-patches.md)) — do not re-add `nautilus-open-any-terminal` (AUR) or code-nautilus to install.sh; they would duplicate the built-in items. rebuild-nautilus.sh removes both if it finds them installed.

## Power profiles

Automatic switching on AC plug/unplug is driven by udev (`assets/99-power.rules`) firing the `acpoweron.service` / `acpoweroff.service` systemd user units in [config/systemd/user/](config/systemd/user/), which call `powerprofilesctl set performance` / `set power-saver` directly (`power-profiles-daemon` is in the package list; Noctalia's battery widget reads/sets the same profiles). The `usb-insert.service` / `usb-remove.service` units play a sound via `paplay` when triggered.

Note that the udev rules contain a literal `USERNAME` token that [install.sh](install.sh) `sed`s into the real user during install — same pattern as `config/noctalia/settings.json`; when editing these files in the repo, leave the token as `USERNAME`.
