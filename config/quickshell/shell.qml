import QtQuick
import Quickshell
import Quickshell.Io
import "modules/startmenu"
import "modules/launcher"
import "modules/calendar"
import "modules/clipboard"
import "modules/quicksettings"
import "modules/bar"

ShellRoot {
    StartMenu             { id: startmenu;     open: false }
    Launcher              { id: launcher;      open: false }
    Calendar              { id: calendar;      open: false }
    Clipboard             { id: clipboard;     open: false }
    BatteryQuickSettings  { id: batteryQS;     open: false }
    AudioQuickSettings    { id: audioQS;       open: false }
    NetworkQuickSettings  { id: networkQS;     open: false }
    Tooltip               { id: tooltip }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.open = !launcher.open; }
    }
    IpcHandler {
        target: "startmenu"
        function toggle(): void { startmenu.open = !startmenu.open; }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { clipboard.open = !clipboard.open; }
    }

    // Only one Quick Settings flyout should be visible at a time.
    function closeOtherQS(keep) {
        if (keep !== batteryQS) batteryQS.open = false;
        if (keep !== audioQS)   audioQS.open   = false;
        if (keep !== networkQS) networkQS.open = false;
    }

    Bar {
        startMenuOpen:  startmenu.open
        launcherOpen:   launcher.open
        clipboardOpen:  clipboard.open
        calendarOpen:   calendar.open
        batteryQSOpen:  batteryQS.open
        audioQSOpen:    audioQS.open
        networkQSOpen:  networkQS.open
        tooltip:        tooltip

        onToggleStartMenu: startmenu.open = !startmenu.open
        onToggleLauncher:  launcher.open  = !launcher.open
        onToggleClipboard: clipboard.open = !clipboard.open
        onToggleCalendar:  calendar.open  = !calendar.open
        onToggleBatteryQS: {
            closeOtherQS(batteryQS);
            batteryQS.open = !batteryQS.open;
        }
        onToggleAudioQS: {
            closeOtherQS(audioQS);
            audioQS.open = !audioQS.open;
        }
        onToggleNetworkQS: {
            closeOtherQS(networkQS);
            networkQS.open = !networkQS.open;
        }
    }
}
