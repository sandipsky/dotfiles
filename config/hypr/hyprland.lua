--  _   _                  _                 _
-- | | | |_   _ _ __  _ __| | __ _ _ __   __| |
-- | |_| | | | | '_ \| '__| |/ _` | '_ \ / _` |
-- |  _  | |_| | |_) | |  | | (_| | | | | (_| |
-- |_| |_|\__, | .__/|_|  |_|\__,_|_| |_|\__,_|
--        |___/|_|
--

require("conf/animations")
require("conf/autostart")
require("conf/environment")
require("conf/keybinds")
require("conf/layout")
require("conf/windowrules")

-- Optional pieces that a scripts/*.sh helper drops into conf/ while what they
-- drive is installed (virtualbox.sh `install` copies assets/hypr/virtualbox.lua
-- in, `remove` deletes it) — pcall so a missing file is not a config error.
pcall(require, "conf/virtualbox")

-- -----------------------------------------------------
-- Monitor
-- -----------------------------------------------------

hl.monitor({
    output   = "",
    mode     = "1920x1080@144",
    position = "auto",
    scale    = 1,
})
