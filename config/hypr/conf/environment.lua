-- -----------------------------------------------------
-- Environment Variables
-- -----------------------------------------------------
--
-- Only compositor-facing variables live here. hl.env applies to Hyprland's
-- own process and the children it forks (autostart, keybinds) — nothing
-- launched through systemd, D-Bus activation or xdg-desktop-portal sees it.
-- App-facing variables (cursor theme, QT_SCALE_FACTOR and the other Qt/toolkit
-- settings) are in config/uwsm/env instead: uwsm exports that into the
-- systemd user environment before starting Hyprland, so Hyprland and every
-- app, however launched, inherit them. Don't add them back here.

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_DRM_NO_ATOMIC", "1")

-- GTK4's Vulkan renderer wakes the runtime-suspended NVIDIA dGPU on every
-- app launch (~1.5s stall). The fix (GDK_DISABLE=vulkan) deliberately lives
-- in /etc/environment (written by install.sh), not here — hl.env would miss
-- dbus-/systemd-activated apps. On a machine installed before this existed,
-- apply it once by hand:  echo 'GDK_DISABLE=vulkan' | sudo tee -a /etc/environment
