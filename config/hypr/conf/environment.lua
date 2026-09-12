-- -----------------------------------------------------
-- Environment Variables
-- -----------------------------------------------------

hl.env("XCURSOR_THEME", "BreezeX-Light")
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_DRM_NO_ATOMIC", "1")

-- GTK4's Vulkan renderer wakes the runtime-suspended NVIDIA dGPU on every
-- app launch (~1.5s stall). The fix (GDK_DISABLE=vulkan) deliberately lives
-- in /etc/environment (written by install.sh), not here — hl.env would miss
-- dbus-/systemd-activated apps. On a machine installed before this existed,
-- apply it once by hand:  echo 'GDK_DISABLE=vulkan' | sudo tee -a /etc/environment

-- QT APPS
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
-- Deliberately no QT_QPA_PLATFORMTHEME: Qt's built-in fallback asks fontconfig
-- for "Sans Serif" 9pt, and fontconfig/fonts.conf maps sans-serif to Fira Sans,
-- so Qt apps get the desktop font at Qt's native 9pt. The gtk3 theme would
-- import the GTK font instead — Fira Sans 12 — which on top of the 1.25
-- QT_SCALE_FACTOR .desktop overrides (OBS, qBittorrent, VirtualBox) made those
-- apps far too big. It would also be ignored by VirtualBox, which forces the
-- xdgdesktopportal theme at startup.
