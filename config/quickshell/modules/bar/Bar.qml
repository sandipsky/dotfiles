import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../styles"
import "components"

PanelWindow {
    id: root

    // Anchor across the bottom edge, full width, fixed height.
    // Leaving `top` unset keeps the bar at the bottom and prevents it
    // from stretching vertically.
    screen: Quickshell.screens[0]
    anchors {
        bottom: true
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
    signal toggleCalendar()

    // Active states — driven by the owning ShellRoot so the corresponding
    // button highlights while its panel is open.
    property bool startMenuOpen: false
    property bool launcherOpen: false
    property bool calendarOpen: false

    Rectangle {
        id: bar
        anchors.fill: parent
        color: Theme.barBg

        // Top hairline border — the bar is flush with the bottom edge,
        // so only the top side ever shows a visible separator.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.barBorder
        }

        // ---- Left side: start button + workspaces ----
        RowLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            spacing: 6

            StartButton {
                Layout.alignment: Qt.AlignVCenter
                active: root.startMenuOpen
                onClicked: root.toggleStartMenu()
            }

            SearchButton {
                Layout.alignment: Qt.AlignVCenter
                active: root.launcherOpen
                onClicked: root.toggleLauncher()
            }

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                count: 6
            }
        }

        // ---- Right side: volume + clock ----
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            spacing: 4

            VolumeIndicator { }

            Clock {
                active: root.calendarOpen
                onLeftClicked: root.toggleCalendar()
            }
        }
    }
}
