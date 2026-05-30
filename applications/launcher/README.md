# Launcher

A minimal GTK4 + libadwaita application launcher — the GTK port of the
Quickshell launcher in
[`config/quickshell/modules/launcher/`](../../config/quickshell/modules/launcher/).
GNOME doesn't run Quickshell, so on a GNOME session this standalone binary
provides the same thing: a dark search box at ~20% from the top that filters
installed apps, doubles as a calculator, and offers a Google-search fallback.

It runs as a **resident background service** (started on login) and pops its
window up **instantly on Alt+Space** — the process is already warm, so there's
no cold-start. A frameless overlay appears focused on a search field and
dismisses itself on **Escape**, on **Alt+Space** again, by clicking outside the
card, or when it loses focus.

### How it covers the screen

The launcher is a screen-covering overlay with the search card floated at 20%
from the top. How that overlay is realized is chosen at runtime:

- **wlroots compositors (Hyprland, sway, …)** — if `gtk4-layer-shell` is
  available and the compositor supports the protocol, it becomes a real
  layer-shell overlay anchored to all four screen edges, on the overlay layer,
  with exclusive keyboard focus — exactly like the Quickshell `PanelWindow`. So
  the *same binary* works as a first-class launcher on Hyprland too.
- **GNOME (mutter)** — has no layer-shell, so it falls back to a maximized
  transparent window. (Fullscreen would get unredirected by mutter, dropping
  the alpha and painting the backdrop solid black on software-rendered VMs;
  maximized windows stay composited.)

There is no `.desktop` entry — it's keybind-driven, not launched from the app
grid.

## How "instant" works

`launcher` is a single-instance GApplication. The systemd user service runs
`launcher --service`, which becomes the resident primary instance: it builds
the window once, keeps it hidden, and holds the process alive. The Alt+Space
keybinding runs `launcher --toggle`, which D-Bus-forwards to that resident
instance and flips the window's visibility — no new process, no rebuild.

## What it does

Type into the box and you get, in order:

1. **Calculator** — if the text is an arithmetic expression containing an
   operator (`+ - * / % ^`, parentheses, decimals), the top row shows `= <value>`.
   Activating it copies the result to the clipboard (via `wl-copy`).
2. **Apps** — up to six matching applications, ranked so names that *start* with
   your query come first. Matches against name, generic name, comment, and
   keywords from the `.desktop` files. Activating launches the app.
3. **Google** — always the last row, opens
   `https://www.google.com/search?q=…` in your default browser.

Navigate with **Up/Down**, activate with **Enter** (or click a row).

## Dependencies

Already on this Arch system after a GTK app build: `gtk4`, `libadwaita`,
`glib2`, `gcc`, `pkgconf`.

Still needed (install once):

```
sudo pacman -S meson ninja wl-clipboard gtk4-layer-shell
```

`wl-clipboard` is only used to copy calculator results; without it the app
falls back to the GTK clipboard (which doesn't survive the process exiting on
Wayland).

`gtk4-layer-shell` is **optional** — it's what makes the launcher a proper
layer-shell overlay on Hyprland/sway. The build auto-detects it
(`dependency('gtk4-layer-shell-0', required: false)` + `-DHAVE_LAYER_SHELL`); if
it's absent the binary still builds and runs, just GNOME-style (maximized).

## Build & install

```
cd applications/launcher
./install.sh
```

`install.sh` checks/installs the dependencies, builds and installs to
`~/.local`, then wires up the service and keybinding for you:

- `~/.local/bin/launcher` — the executable
- `~/.local/share/systemd/user/launcher.service` — the resident service,
  symlinked into `~/.config/systemd/user/graphical-session.target.wants/` so it
  starts on login
- a GNOME custom keybinding: **Alt+Space → `launcher --toggle`** (GNOME's
  default Alt+Space window-menu binding is cleared to make room)

Manual build, if you prefer:

```
meson setup build --prefix="$HOME/.local"
meson compile -C build
./build/src/launcher --toggle   # one-shot window, no service
```

## Service control

```
systemctl --user start   launcher.service   # start it now (no need to log out)
systemctl --user status  launcher.service
systemctl --user restart launcher.service   # after rebuilding
```

## Changing the keybinding

Re-run with a different shortcut, or edit it in **Settings → Keyboard →
View and Customize Shortcuts → Custom Shortcuts → Launcher**. The command is the
absolute path `~/.local/bin/launcher --toggle` so it works regardless of the
session `PATH`.

`install.sh` only sets up the **GNOME** keybinding (via gsettings). On Hyprland
the keybind lives in your Hyprland config instead — add to
[`config/hypr/conf/keybinds.conf`](../../config/hypr/conf/keybinds.conf):

```
bind = ALT, SPACE, exec, ~/.local/bin/launcher --toggle
```

and start the service the same way (`systemctl --user start launcher.service`,
or an `exec-once` in autostart). Note that on Hyprland the Quickshell launcher
already covers this — running both is redundant.

## Layout map

```
data/
├── launcher.service                 # systemd user unit (resident service)
├── dev.sandip.Launcher.svg          # color app icon
├── dev.sandip.Launcher-symbolic.svg # symbolic app icon
├── launcher.gresource.xml           # bundles style.css + the 3 glyph icons
├── style.css                        # dark theme, mirrors Quickshell Theme.qml
└── icons/{search,calculator,web}.svg

src/
├── main.c                       # entry point
├── launcher-application.{c,h}   # resident GApplication: --service / --toggle, dark scheme + CSS
├── launcher-window.{c,h}        # the search box, results list, keyboard nav, show/hide/toggle
├── launcher-result.{c,h}        # LauncherResult GObject (app / calc / google) + activation
├── launcher-result-row.{c,h}    # row widget bound to a LauncherResult
└── launcher-search.{c,h}        # query -> result list; the calculator evaluator
```

## Styling

Colors, radii, and fonts in `data/style.css` are copied from the Quickshell
singleton [`styles/Theme.qml`](../../config/quickshell/styles/Theme.qml)
(`launcherBg #202020`, `launcherBorder #383838`, radius `28`, Fira Sans). To
restyle, edit `style.css` and rebuild.
