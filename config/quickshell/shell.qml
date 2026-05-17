import QtQuick
import Quickshell
import "modules/startmenu"
import "modules/launcher"
import "modules/calendar"
import "modules/clipboard"
import "modules/bar"

ShellRoot {
    StartMenu { id: startmenu; open: false }
    Launcher  { id: launcher;  open: false }
    Calendar  { id: calendar;  open: false }
    Clipboard { id: clipboard; open: false }
    Tooltip   { id: tooltip }

    Bar {
        startMenuOpen: startmenu.open
        launcherOpen:  launcher.open
        clipboardOpen: clipboard.open
        calendarOpen:  calendar.open
        tooltip:       tooltip

        onToggleStartMenu: startmenu.open = !startmenu.open
        onToggleLauncher:  launcher.open  = !launcher.open
        onToggleClipboard: clipboard.open = !clipboard.open
        onToggleCalendar:  calendar.open  = !calendar.open
    }
}
