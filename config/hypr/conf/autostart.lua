-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("qs -c noctalia-shell")
end)
