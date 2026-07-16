# Noctalia fork — local patch reference

Upstream Noctalia is planning a QML → C++ rewrite (memory issues). This file documents
every local change carried on top of the vendored upstream snapshot at
[config/quickshell/noctalia-shell/](../config/quickshell/noctalia-shell/), described
**by behavior** rather than by diff, so the same customizations can be re-implemented
on the future C++ codebase (or any newer QML release).

- **Baseline:** upstream Noctalia v4.7.7, vendored in commit `2d6820d` ("fork og noctalia").
- **Raw diff of everything below:**
  `git diff 2d6820d..HEAD -- config/quickshell/noctalia-shell`
- **Patch commits, in order:** `b68ce0d` ui modification 1 · `0f72d0b` lockscreen ·
  `232ed1b` noctalia control panel · `4950c2f` bar auto hide fix · `116114c` vpm (VPN panel) ·
  `a407da6` refresh rate and brightness · `86a9a28` workspace · `36ed9e1` lockscreen adjust

Summary of features (each detailed below):

1. Windows-11-style two-stage lock screen (full rewrite) + custom lock wallpaper/font settings
2. Bar widget upgrades: ActiveWindow (title mode, sideways vertical title), Taskbar
   (stable pinned order, icon-refresh fix, item gap), Workspace (fixed workspace count,
   no active-pill growth, scroll wrap toggle)
3. Launcher: single dock-pinned-apps source, plain alphabetical sort
4. Control center: media and system-monitor split into separate cards, sysmon as a horizontal row
5. Bar auto-hide: "show when workspace is empty" option
6. VPN panel: full profile manager (connect/disconnect/import/delete via nmcli)
7. Battery panel extras: brightness slider + Hyprland refresh-rate switcher
8. Bar auto-hide: v5-style slide animation (replaces the opacity fade)

---

## 1. Lock screen — two-stage "Windows 11 style" (biggest change)

Files: `Modules/LockScreen/LockScreenPanel.qml` (**rewritten**, ~1450 lines → 640),
`Modules/LockScreen/LockScreen.qml`, `Modules/LockScreen/LockScreenBackground.qml`,
`Modules/Panels/Settings/Tabs/LockScreen/AppearanceSubTab.qml`, `Commons/Settings.qml`.
Commits: `0f72d0b`, `232ed1b` (button size), `36ed9e1` (sizing polish).

The upstream lock screen (header + clock styles + media controls + weather) was replaced
with a minimal two-stage design driven by a `stage` property (`"cover"` / `"login"`):

- **Cover stage:** only a big 12-hour clock (72 pt, bold, no leading zero, no AM/PM) and
  a date line (`dddd, MMMM d`), horizontally centered at ~38 % of screen height.
- **Login stage:** circular avatar (130 px outer ring / 124 px image, from
  `Settings.data.general.avatarImage`), user display name (Fira Sans SemiBold, XXXL,
  semi-bold), and a compact 200×30 password capsule.
- **Transitions:** any click or key press on the cover advances to login (printable keys
  flow into the password field; the key handling lives in LockScreen.qml `Keys.onPressed`).
  Escape returns to the cover and clears the typed password (unless a countdown is active,
  where it cancels the countdown). Cover/login cross-fade with a small vertical slide
  (opacity + y `Behavior`s, `Easing.OutCubic`). Entering login focuses the password input;
  changing stage closes the session menu. If `general.autoStartAuth` is set, it jumps
  straight to login and starts auth (fingerprint-style flow).
- **Password capsule details:** password dots use the upstream fun-shape icons when
  `general.passwordChars` is on; eye button toggles plain-text view; arrow submit button;
  caret is a hand-drawn 2px rectangle that blinks — smooth fade when
  `general.lockScreenAnimations` is true, else a cheap 530 ms Timer toggle (explicitly to
  avoid per-frame GPU repaints); Ctrl+A selects all; caret x is computed from cursor
  position (FontMetrics in plain mode, proportional in dots mode).
- **Bottom-right (both stages):** battery icon + percentage (icon tinted primary while
  charging), and a power button (baseSize 30, shown per
  `general.showSessionButtonsOnLockScreen`) opening a small popup menu anchored above it:
  Suspend, Logout, (Hibernate if `general.showHibernateOnLockScreen`), Reboot, Shutdown —
  shutdown row highlights in error color. Menu actions go through the upstream countdown
  timer (`general.enableLockScreenCountdown` / `lockScreenCountdownDuration`; second click
  executes immediately).
- **Removed from upstream:** `LockScreenHeader` usage, analog/digital/custom clock styles
  and clock-format editor, compact-lockscreen mode, lock-screen media controls, weather.
  Info/error/countdown toast margins in LockScreen.qml changed to a fixed 200 px bottom
  margin (compact-mode conditional removed).

**New settings** (in `Commons/Settings.qml` under `general`):

- `lockScreenWallpaper` (string, default `""`) — custom lock background image. Resolved in
  `LockScreenBackground.qml`: when set it overrides the per-screen wallpaper (and works
  even when wallpaper is disabled or in solid-color mode); empty falls back to upstream
  behavior. Settings UI: file picker in Settings → Lock Screen → Appearance.
- `lockScreenFont` (string, default `""` → falls back to `ui.fontFixed`) — font family for
  the cover clock/date. Settings UI: searchable font combo (FontService.availableFonts).

The Settings → Lock Screen → Appearance tab was rebuilt around these two controls
(clock-style/format/compact/media-control toggles removed).

Note: the login-stage name label hardcodes `family: "Fira Sans SemiBold"` (installed by
this repo's install.sh font step) — it does *not* follow `lockScreenFont`.

## 2. Bar widgets

### 2a. ActiveWindow (`Modules/Bar/Widgets/ActiveWindow.qml`)

Commits `b68ce0d`, `0f72d0b`. New per-widget settings (defaults registered in
`Services/UI/BarWidgetRegistry.qml`, UI in
`Modules/Panels/Settings/Bar/WidgetSettings/ActiveWindowSettings.qml`):

- `titleMode`: `"title"` (default) | `"appname"` — appname shows the app's .desktop name
  (resolved via ThemeIcons/DesktopEntries from the window's appId, falling back to the
  appId, then the title).
- `noWindowText`: `"default"` ("No active window") | `"desktop"` ("Desktop") | `"none"` (empty)
  — what the text shows when nothing is focused.
- The app icon is hidden when no window is focused (`showIcon && hasFocusedWindow`).
- **Vertical bar sideways title:** vertical bars previously showed icon-only; now they
  render the title rotated 90°, below the icon, with the widget's length along the bar
  computed from a hidden measuring NText, clamped to `maxWidth`, with an animated
  height Behavior.
- **Async desktop-entry fix:** an `iconRevision` counter bumped from
  `DesktopEntries.applications.onValuesChanged` forces `windowTitle`/`getAppIcon()` to
  re-evaluate once .desktop entries finish loading (otherwise names/icons resolved too
  early stick wrong). Also stopped lower-casing appIds before `ThemeIcons.iconForAppId`
  so user .desktop overrides with case-sensitive ids match.

### 2b. Taskbar (`Modules/Bar/Widgets/Taskbar.qml`)

Commit `b68ce0d`:

- **Stable pinned ordering:** `sortApps()` rewritten — pinned apps always occupy the slots
  given by `Settings.data.dock.pinnedApps` order, whether running or not, so launching a
  pinned app never moves it; unpinned running apps follow in transient session order.
  (Matching is by normalized appId against the pinned id or its resolved desktop-entry id.)
- **Icon-refresh fix:** same async-desktop-entries problem as ActiveWindow — an
  `iconRevision` counter + `DesktopEntries.applications.onValuesChanged` connection clears
  the desktop-entry-id cache and forces icon `source` re-evaluation.
- `itemGap` per-widget setting (int px, default 2, spinbox 0–24 in TaskbarSettings) —
  replaces hardcoded `Style.marginXXS` row/column spacing between taskbar items.

### 2c. Workspace (`Modules/Bar/Widgets/Workspace.qml`)

Commits `b68ce0d`, `86a9a28`. New per-widget settings (registry defaults + WorkspaceSettings UI):

- `workspaceMode`: `"dynamic"` (default, upstream behavior) | `"fixed"`, plus
  `fixedWorkspaces` (int, default 5, spinbox 1–20, only visible in fixed mode). Fixed mode
  always renders workspaces 1..N — missing ones as empty placeholder pills — and appends
  any real workspace with idx > N so the focused one never disappears. `hideUnoccupied` is
  ignored in fixed mode (and its toggle hidden).
- **No active-pill growth:** removed the 2.2× width/height factor on the active workspace —
  all pills are the same size regardless of focus.
- `wrapWorkspaces` (bool, default true; toggle only visible when scroll wheel is enabled) —
  when false, scrolling on the widget stops at the first/last workspace instead of cycling
  around. (Also fixed the negative-modulo when wrapping backwards.)

## 3. Launcher applications provider

`Modules/Panels/Launcher/Providers/ApplicationsProvider.qml`, commit `b68ce0d`:

- Pinned apps now come from **`Settings.data.dock.pinnedApps`** everywhere (was
  `appLauncher.pinnedApps`) — one pin list shared with the dock/taskbar; the launcher's
  pin/unpin context action edits the dock list too.
- Launcher no longer auto-selects the "Pinned" category on open — always opens on "all".
- Results are plain alphabetical: removed pinned-first ordering and the
  `sortByMostUsed` usage-count ordering for the empty query, and removed pinned-first
  re-ranking of fuzzy search results (pure fuzzysort order).

## 4. Control center cards

Commit `232ed1b`. Files: `Commons/Settings.qml`,
`Modules/Panels/ControlCenter/ControlCenterPanel.qml`,
`Modules/Panels/Settings/Tabs/ControlCenter/ControlCenterTab.qml`,
`Modules/Cards/SystemMonitorCard.qml`.

- Upstream's combined `media-sysmon-card` was split into two independently toggleable
  cards: `media-card` (height 220) and `sysmon-card` (height 84). The default
  `controlCenter.cards` list in Settings.qml replaces `media-sysmon-card` with both new
  ids — **live settings.json files carrying the old id keep working upstream-side but the
  card won't render; migrate the id if reusing an old settings.json.**
- `SystemMonitorCard` layout flipped from a 4-row Column (sidebar style) to a 4-column Row
  of circular gauges (CPU %, CPU temp, RAM, disk) so it works as a short full-width card.
- Also (`Modules/MainScreen/BarContentWindow.qml`) the auto-hide timer gained a
  `BarService.shouldStayVisible()` check — part of feature 5.

## 5. Bar auto-hide: "Show when workspace is empty"

Commits `232ed1b` + `4950c2f` (startup/race fixes). Files: `Services/UI/BarService.qml`,
`Modules/MainScreen/BarContentWindow.qml`, `Commons/Settings.qml`,
`Modules/Panels/Settings/Tabs/Bar/AppearanceSubTab.qml`.

New setting `bar.showWhenWorkspaceEmpty` (bool, default false; toggle in Settings → Bar →
Appearance): when the bar is in `auto_hide` mode, it stays visible while the active
workspace on that screen has no windows, and resumes the normal auto-hide cycle once a
window appears.

Implementation notes worth carrying over:

- `BarService.shouldStayVisible(screenName)` = setting on && display mode is auto_hide &&
  active workspace on that screen unoccupied (respecting `globalWorkspaces`). The bar
  window's hide timer checks it before hiding.
- `updateEmptyWorkspaceVisibility()` runs on `CompositorService.onWorkspacesChanged` /
  `onWindowListChanged` (via `Qt.callLater`), on the setting toggling, and shows/hides bars
  accordingly (when the workspace becomes occupied it re-emits an unhover to restart the
  hide timer).
- **Startup races (the `4950c2f` fixes, easy to reintroduce):** iterate real
  `Quickshell.screens`, not the lazily-populated auto-hide state map (which stays empty
  while a bar starts hidden — its content never loads, so it never registers); seed the
  auto-hide state when a bar reports ready; and re-evaluate on a one-shot 2 s timer after
  startup because settings and workspace lists load asynchronously.

## 6. VPN panel

Commit `116114c`. New files: `Modules/Panels/VPN/VPNPanel.qml`; extended:
`Services/Networking/VPNService.qml`, `Modules/Bar/Widgets/VPN.qml`,
`Modules/MainScreen/MainScreen.qml` (panel instantiated per screen as `vpnPanel`),
`Assets/Translations/en.json` (`vpn.panel.*` strings).

Upstream's VPN bar widget only toggled connections from a context menu. Added a full
SmartPanel (440×500) opened by **left-clicking** the VPN bar widget (right-click keeps the
upstream context menu; tooltip suppressed while the panel is open):

- Lists all NetworkManager VPN/WireGuard profiles, active first; each row is an NToggle
  (connect/disconnect via the existing VPNService) with status text
  (connected/disconnected/connecting/disconnecting/removing), all rows disabled while any
  operation is in flight.
- **Delete** button per row with an inline two-step confirm (row swaps to a
  confirm/cancel state); runs `nmcli connection delete uuid <uuid>`, success detected by
  "successfully deleted" on stdout, toast + list refresh after 500 ms.
- **Import** button (header + empty state) opens a file picker (defaults to ~/Downloads,
  filters `*.conf` / `*.ovpn`); runs `nmcli connection import type <wireguard|openvpn>
  file <path>` — type inferred from the extension (`.ovpn` → openvpn, else wireguard);
  success detected by "successfully added"; errors surface as warning toasts using the
  first stderr line.
- Empty state with shield-off icon, hint text, and an Import button. Panel refreshes the
  profile list every time it opens.
- VPNService gained `removing`/`removingUuid`/`importing` state properties alongside the
  existing connect/disconnect ones.

## 7. Battery panel: brightness slider + refresh-rate switcher

Commit `a407da6`. New file: `Services/Compositor/RefreshRateService.qml`; extended:
`Modules/Panels/Battery/BatteryPanel.qml`, `Modules/Bar/Widgets/Battery.qml`,
`Modules/Panels/Settings/Bar/WidgetSettings/BatterySettings.qml`, registry defaults,
`en.json`/`en-GB.json` (`bar.battery.show-*`, `common.refresh-rate`, `toast.refresh-rate.*`).

Two new Battery **widget** settings (passed into the panel via `panelID`, like upstream's
`showPowerProfiles`): `showBrightnessSlider` and `showRefreshRateSwitcher` (both default
false — enabled per-widget in bar settings; note this machine's live settings.json /
`config/noctalia/settings.json` snapshot is where the enabled state actually lives).

- **Brightness slider card:** controls the monitor the panel is on
  (`BrightnessService.getMonitorForScreen`), shown only if brightness control is
  available. Local value + 100 ms debounce before calling `setBrightness` (avoids flooding
  brightnessctl/ddc), external changes sync back unless the user is dragging, scroll wheel
  on the slider steps by `Settings.data.brightness.brightnessStep`.
- **Refresh-rate switcher card (Hyprland only):** `RefreshRateService` is a singleton that
  parses `hyprctl monitors -j`, collecting the distinct rounded rates from
  `availableModes` strings (`"1920x1080@60.00Hz"`) **at the monitor's current resolution
  only**; a display is "supported" when it has >1 rate. Switching runs
  `hyprctl keyword monitor <name>,<WxH>@<rate>,<XxY>,<scale>[,transform,<t>]` —
  preserving position, scale, and transform — then toasts success/failure and re-queries.
  A `revision` counter property is bumped on every re-query so QML bindings re-evaluate
  (map properties don't notify on deep change). The panel refreshes rates on open.
  Caveat carried by design: a rate set this way is a runtime `hyprctl keyword` override —
  Hyprland's monitors.conf line reapplies on config reload.

---

## 8. Bar auto-hide: v5-style slide animation

Files: `Modules/MainScreen/BarContentWindow.qml`,
`Modules/MainScreen/Backgrounds/BarBackground.qml`.

Upstream v4 hides/reveals the auto-hide bar with a plain 150 ms opacity fade. The C++
v5 rewrite instead **slides** the bar fully off its screen edge with no fade at all
(`src/shell/bar/bar.cpp`: `hideOpacity` drives `slideRoot` position only, opacity stays
1.0; 200 ms, `EaseOutCubic` on reveal, `EaseInQuad` on hide, 4 px overshoot). This patch
replicates that in the QML tree:

- Both files share a `hideProgress` property (0 = shown, 1 = hidden) with a
  `Behavior`/`NumberAnimation` of duration `Style.animationNormal * 2/3` (= 200 ms at
  animation speed 1, scales with the setting, 0 when animations are disabled) and easing
  bound to direction: `isHidden ? Easing.InQuad : Easing.OutCubic`.
- **BarContentWindow** translates the bar content (`transform: Translate`) toward the
  bar's edge by `barHeight + edge margin + overshoot`; the content clips at the window
  edge, which coincides with the screen edge for `simple` bars. `windowHideTimer` (which
  drops window visibility/input after hiding) now waits for the slide duration instead of
  `Style.animationFast`.
- **BarBackground** (the ShapePath in MainScreen's unified shadow Shape) folds
  `slideDx/slideDy * hideProgress` into `barMappedPos`, so the background and its drop
  shadow travel with the content. Slide deltas are derived from bar x/y/size so content
  and background move at identical speeds.
- **Overshoot must clear the drop shadow**: the background lives in a full-screen window,
  so a shape parked only 4 px off-screen still bleeds its shadow (up to
  `Style.shadowBlurMax` = 22 px + offset) back onto the edge. Both files use
  `slideOvershoot = 4 + Style.shadowBlurMax + 8`.
- **Framed bars can't slide** (the background is a full-screen frame) and **floating
  bars clip** at their window edge before clearing the screen — both keep an opacity
  fade (`opacityFactor`/content `opacity` = `1 - hideProgress`); `simple` bars get the
  pure slide.

## Re-applying on a new codebase

Priority if porting incrementally: the lock screen (1) and the taskbar/workspace behavior
(2b, 2c) are the changes most visible day-to-day; the ActiveWindow/Taskbar
async-desktop-entry fixes (2a/2b) may already be fixed upstream by then — test before
porting. Check whether upstream has since grown equivalents for the VPN manager,
brightness/refresh-rate controls, fixed workspaces, and empty-workspace bar pinning
before re-implementing them.

Settings keys to preserve (so existing `settings.json` keeps working):
`general.lockScreenWallpaper`, `general.lockScreenFont`, `bar.showWhenWorkspaceEmpty`,
widget settings `titleMode`, `noWindowText` (ActiveWindow), `itemGap` (Taskbar),
`workspaceMode`, `fixedWorkspaces`, `wrapWorkspaces` (Workspace), `showBrightnessSlider`,
`showRefreshRateSwitcher` (Battery), and the `media-card` / `sysmon-card` control-center
card ids. The dock/launcher share `dock.pinnedApps`.

To regenerate the authoritative diff at any time:

```sh
git diff 2d6820d..HEAD -- config/quickshell/noctalia-shell > /tmp/noctalia-local-patches.diff
```

If this doc drifts from the tree, the diff wins. When adding new patches to the fork,
append them here (feature description + files + settings keys), not just to git history.
