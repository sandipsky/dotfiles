import QtQuick
import Quickshell
import "modules/startmenu"
import "modules/launcher"
import "modules/calendar"

ShellRoot {
    // Only one of these should be `open` at a time (the keyboard-focus
    // ones grab exclusively). Calendar doesn't grab keyboard so it can
    // coexist visually, but for testing keep one open at a time.
    StartMenu { open: false }
    Launcher  { open: false }
    Calendar  { open: true  }
}
