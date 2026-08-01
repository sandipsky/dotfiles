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

-- GTK APPS
-- GTK 4.22's Vulkan renderer enumerates all GPUs at startup, waking the
-- runtime-suspended NVIDIA dGPU (~1.5s stall on every app launch) even though
-- GTK renders on the Intel iGPU anyway. Force the GL renderer instead.
hl.env("GDK_DISABLE", "vulkan")

-- QT APPS
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
