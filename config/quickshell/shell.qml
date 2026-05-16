import QtQuick
import Quickshell
import "modules/startmenu"
import "modules/launcher"

ShellRoot {
    // Only one of these should be `open` at a time (both grab keyboard
    // exclusively). For now StartMenu is hidden so the launcher is the
    // one shown on shell startup.
    StartMenu { open: false }
    Launcher  {}
}
