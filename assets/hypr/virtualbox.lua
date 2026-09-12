-- -----------------------------------------------------
-- VirtualBox — installed by scripts/virtualbox.sh
-- -----------------------------------------------------
-- Lives at ~/.config/hypr/conf/virtualbox.lua only while VirtualBox is
-- installed: virtualbox.sh `install` copies it there and `remove` deletes it;
-- hyprland.lua requires it with pcall, so its absence is not an error.
--
-- The VM itself is not part of the dotfiles — copy "~/VirtualBox VMs/<VM_NAME>"
-- back from the backup drive (VirtualBox picks it up via Machine > Add).

local mainMod = "SUPER"
local VM_NAME = "Windows 10"

-- Super+Shift+Return: start the VM (a no-op when it is already running —
-- VBoxManage refuses to start a locked machine).
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd('VBoxManage startvm "' .. VM_NAME .. '"'))

-- Maximize the VM window on Hyprland's side only: "1 0" is fullscreen_state
-- internal=maximize, client=none — the window fills the workspace with the
-- bar still showing (the Super+F state, not the exclusive Super+Shift+F one)
-- and VirtualBox is never told, so it stays in its normal windowed mode
-- instead of switching to its own fullscreen (mini toolbar, Host+F to leave).
-- The guest resizes to the window through the guest additions. Only this VM:
-- other machines (class "VirtualBox Machine" too) open as normal windows.
-- Hyprland regexes are RE2 full matches, hence the trailing ".*".
hl.window_rule({
    name  = "virtualbox-vm-maximize",
    match = { class = "^VirtualBox Machine$", title = "^" .. VM_NAME .. " \\[.*" },
    fullscreen_state = "1 0",
})
