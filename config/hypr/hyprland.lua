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

-- -----------------------------------------------------
-- Monitor
-- -----------------------------------------------------

hl.monitor({
    output   = "",
    mode     = "1920x1080@144",
    position = "auto",
    scale    = 1,
})
