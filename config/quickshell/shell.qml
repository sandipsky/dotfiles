import QtQuick
import Quickshell
import Quickshell.Io
import "modules/startmenu"
import "modules/launcher"
import "modules/calendar"
import "modules/clipboard"
import "modules/quicksettings"
import "modules/bar"
import "services"

ShellRoot {
    PinnedApps              { id: pinnedApps }
    StartMenu             { id: startmenu;     open: false; pinned: pinnedApps }
    Launcher              { id: launcher;      open: false }
    Calendar              { id: calendar;      open: false }
    Clipboard             { id: clipboard;     open: false }
    BatteryQuickSettings    { id: batteryQS;     open: false }
    AudioQuickSettings      { id: audioQS;       open: false }
    NetworkQuickSettings    { id: networkQS;     open: false }
    BluetoothQuickSettings  { id: bluetoothQS;   open: false }
    Tooltip                 { id: tooltip }
    PinnedContextMenu       { id: pinnedMenu; pinned: pinnedApps }

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
    IpcHandler {
        target: "bluetoothqs"
        function toggle(): void {
            closeOtherQS(bluetoothQS);
            bluetoothQS.open = !bluetoothQS.open;
        }
    }

    // Only one Quick Settings flyout should be visible at a time.
    function closeOtherQS(keep) {
        if (keep !== batteryQS)   batteryQS.open   = false;
        if (keep !== audioQS)     audioQS.open     = false;
        if (keep !== networkQS)   networkQS.open   = false;
        if (keep !== bluetoothQS) bluetoothQS.open = false;
    }

    // Forward power-profile changes from the quick-settings tile to the bar
    // so the battery glyph (BatterySaver family) updates instantly instead
    // of waiting for the bar indicator's own 10 s poll.
    Connections {
        target: batteryQS
        function onProfileChanged() { bar.setPowerProfile(batteryQS.profile); }
    }

    Bar {
        id: bar
        startMenuOpen:   startmenu.open
        launcherOpen:    launcher.open
        clipboardOpen:   clipboard.open
        calendarOpen:    calendar.open
        batteryQSOpen:   batteryQS.open
        audioQSOpen:     audioQS.open
        networkQSOpen:   networkQS.open
        bluetoothQSOpen: bluetoothQS.open
        tooltip:         tooltip
        pinned:          pinnedApps

        onPinnedContextRequested: (id, screenX) => pinnedMenu.show(id, screenX)

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
        onToggleBluetoothQS: {
            closeOtherQS(bluetoothQS);
            bluetoothQS.open = !bluetoothQS.open;
        }
    }
}
