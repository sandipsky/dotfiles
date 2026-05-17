import QtQuick
import Quickshell
import "modules/startmenu"
import "modules/launcher"
import "modules/calendar"
import "modules/bar"

ShellRoot {
    StartMenu { id: startmenu; open: false }
    Launcher  { id: launcher;  open: false }
    Calendar  { id: calendar;  open: false }

    Bar {
        startMenuOpen: startmenu.open
        launcherOpen:  launcher.open
        calendarOpen:  calendar.open

        onToggleStartMenu: startmenu.open = !startmenu.open
        onToggleLauncher:  launcher.open  = !launcher.open
        onToggleCalendar:  calendar.open  = !calendar.open
    }
}
