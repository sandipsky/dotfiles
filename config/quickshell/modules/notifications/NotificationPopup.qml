import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../styles"
import "components"

// Full-screen overlay that draws the current notification stack at the
// top-center of the screen. Input is masked to the cards themselves so
// the surrounding area stays click-through (background apps still react
// to clicks where there's no notification).
PanelWindow {
    id: root

    // The Notifications service from shell.qml. We bind to its `popups`
    // array and render one NotificationCard per entry.
    property var service: null

    screen: Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Restrict input to the visible card stack so the rest of the screen
    // is click-through (matches the Tooltip pattern).
    mask: Region { item: stack }

    Column {
        id: stack
        // Bottom-right corner, sitting above the bar's exclusive zone.
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.barHeight + 20
        spacing: 12

        Repeater {
            model: root.service ? root.service.popups : []
            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                onDismissAllRequested: if (root.service) root.service.dismissAll()
            }
        }
    }
}
