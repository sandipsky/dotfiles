import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../styles"
import "components"

PanelWindow {
    id: root

    // Anchor across the top edge, full width, fixed height.
    // Leaving `bottom` unset keeps the bar pinned to the top and prevents
    // it from stretching vertically.
    screen: Quickshell.screens[0]
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    // Sit on the Top layer (above normal windows but below overlays like
    // the start menu / launcher) and reserve our height so maximized
    // windows don't render underneath us.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: Theme.barHeight
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    signal toggleStartMenu()
    signal toggleLauncher()
    signal toggleClipboard()
    signal toggleCalendar()
    signal toggleBatteryQS()
    signal toggleAudioQS()
    signal toggleNetworkQS()
    signal toggleBluetoothQS()
    signal togglePowerMenu()

    // Active states — driven by the owning ShellRoot so the corresponding
    // button highlights while its panel is open.
    property bool startMenuOpen: false
    property bool launcherOpen: false
    property bool clipboardOpen: false
    property bool calendarOpen: false
    property bool batteryQSOpen: false
    property bool audioQSOpen: false
    property bool networkQSOpen: false
    property bool bluetoothQSOpen: false
    property bool powerMenuOpen: false

    // Shared tooltip overlay (instantiated in shell.qml). Indicators on
    // the right side push text + screen-x into it on hover.
    property var tooltip

    // Optimistic power-profile override pushed in from shell.qml whenever
    // the BatteryQuickSettings tile cycles the profile. Lets the battery
    // glyph flip to the BatterySaver family without waiting for the
    // indicator's own 10-second poll.
    function setPowerProfile(p) {
        if (p && p.length > 0) battery.profile = p;
    }

    Rectangle {
        id: bar
        anchors.fill: parent
        color: Theme.barBg

        // Fitt's Law hot corner: extends the start-button hit area to the
        // top-left screen corner so slamming the cursor there toggles
        // the menu, Windows-style. Sits beneath the RowLayout so the
        // visible button still owns its own hover/click.
        Item {
            id: startHotCorner
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // Cover the button itself plus the 6 px left margin.
            width: 6 + 32

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.toggleStartMenu()
            }
        }

        // ---- Left side: start button + workspaces ----
        RowLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            spacing: 4

            StartButton {
                Layout.alignment: Qt.AlignVCenter
                active: root.startMenuOpen
                onClicked: root.toggleStartMenu()
            }

            Workspaces {
                Layout.fillHeight: true
                count: 6
            }

            FocusedApp {
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // ---- Center: clock ----
        Clock {
            anchors.centerIn: parent
            active: root.calendarOpen
            onLeftClicked: root.toggleCalendar()
        }

        // ---- Right side: tray indicators + power ----
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            spacing: 0

            ClipboardButton {
                active: root.clipboardOpen
                onClicked: root.toggleClipboard()
            }

            CpuIndicator {
                tooltip: root.tooltip
            }

            MemoryIndicator {
                tooltip: root.tooltip
            }

            BluetoothIndicator {
                tooltip: root.tooltip
                onClicked: root.toggleBluetoothQS()
            }

            NetworkIndicator {
                tooltip: root.tooltip
                onClicked: root.toggleNetworkQS()
            }

            BatteryIndicator {
                id: battery
                tooltip: root.tooltip
                onClicked: root.toggleBatteryQS()
            }

            VolumeIndicator {
                tooltip: root.tooltip
                onClicked: root.toggleAudioQS()
            }

            PowerButton {
                active: root.powerMenuOpen
                onClicked: root.togglePowerMenu()
            }
        }
    }
}
