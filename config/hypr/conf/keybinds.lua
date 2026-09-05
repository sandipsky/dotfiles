-- -----------------------------------------------------
-- Variables
-- -----------------------------------------------------

local mainMod = "SUPER"

-- Default applications
local terminal    = "alacritty"
local browser     = "google-chrome-stable"
local filemanager = "nautilus"
local calculator  = "gnome-calculator"

-- hypr-shell: keybind actions go through the running instance's GApplication
local function shell(args)
    return hl.dsp.exec_cmd("/home/USERNAME/.local/bin/hypr-shell " .. args)
end
-- volume / brightness: wpctl and brightnessctl (5% steps);
-- hypr-shell's OSD reacts to the resulting PipeWire / backlight changes
local volume_up   = hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
local volume_down = hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
local brightness_up   = hl.dsp.exec_cmd("brightnessctl -q s +5%")
local brightness_down = hl.dsp.exec_cmd("brightnessctl -q s 5%-")

-- -----------------------------------------------------
-- Key bindings
-- -----------------------------------------------------

-- Applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("lutris"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(filemanager .. " --new-window"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(filemanager .. " admin://"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(calculator))
hl.bind(mainMod .. " + P", shell("--wallpaper-next"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + Z", hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + tab", hl.dsp.window.cycle_next())

hl.bind(mainMod .. " + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + up",   hl.dsp.window.resize({ x = 100,  y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))

-- -----------------------------------------------------
-- Workspaces
-- -----------------------------------------------------

for i = 1, 6 do
    hl.bind(mainMod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mainMod .. " + CTRL + h", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + CTRL + l", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "r+1", follow = true }))

hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ workspace = "r+1", follow = true }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "r+1", follow = true }))

-- -----------------------------------------------------
-- Actions
-- -----------------------------------------------------

hl.bind("ALT + space", shell("--launcher"))
hl.bind(mainMod .. " + SUPER_L", shell("--launcher"))
hl.bind(mainMod .. " + V", shell("--clipboard"))
hl.bind(mainMod .. " + A", shell("--control-center"))
hl.bind(mainMod .. " + X", shell("--session"))
hl.bind(mainMod .. " + L", shell("--lock"))

hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("virsh --connect qemu:///system start win; virt-viewer --connect qemu:///system win"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("env HS_SETTINGS_PAGE=wallpaper_page /home/USERNAME/.local/bin/hypr-shell-settings"))

hl.bind("switch:Lid Switch", shell("--lock-and-suspend"), { locked = true })

hl.bind(mainMod .. " + I", brightness_down)
hl.bind(mainMod .. " + O", brightness_up)

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd('grim && notify-send -u normal -a "Snipping Tool" "Screenshot Captured" "Screenshot saved to /home/Pictures folder."'))

-- -----------------------------------------------------
-- Fn / Media keys
-- -----------------------------------------------------

hl.bind("XF86MonBrightnessUp",   brightness_up)
hl.bind("XF86MonBrightnessDown", brightness_down)
hl.bind("XF86AudioRaiseVolume",  volume_up)
hl.bind("XF86AudioLowerVolume",  volume_down)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("XF86ScreenSaver",       shell("--lock"))
hl.bind("Print",                 hl.dsp.exec_cmd("grim - | wl-copy"))
