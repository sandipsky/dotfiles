-- -----------------------------------------------------
-- Layout
-- -----------------------------------------------------

hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 2,
        border_size = 1,
        layout      = "dwindle",
        col = {
            active_border = "rgba(bbbbbbaa)",
        },
    },

    input = {
        numlock_by_default = true,
        follow_mouse       = 1,
        mouse_refocus      = false,
        sensitivity        = 0, -- -1.0 - 1.0, 0 means no modification.
        touchpad = {
            natural_scroll = true,
        },
    },

    xwayland = {
        force_zero_scaling = true,
    },

    decoration = {
        active_opacity     = 1,
        inactive_opacity   = 1,
        fullscreen_opacity = 1,

        rounding = 10,

        blur = {
            enabled  = true,
            size     = 8,
            passes   = 2,
            vibrancy = 0.1696,
        },

        shadow = {
            enabled = false,
        },
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },

    binds = {
        allow_workspace_cycles = true,
    },
})

hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "float" })
