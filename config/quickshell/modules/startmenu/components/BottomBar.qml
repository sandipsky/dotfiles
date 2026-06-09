import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../styles"

// Footer row: search field, power icon — transparent background.
RowLayout {
    id: root

    signal togglePowerMenu()

    // Search signals/state, forwarded from the embedded SearchBar.
    signal searchAccepted()
    signal searchEscape()
    signal searchUp()
    signal searchDown()
    property alias searchText: searchBar.text
    function clearSearch() { searchBar.clear(); }
    function focusSearch() { searchBar.focusInput(); }

    // Driven by StartMenu so the button keeps the hover-bg highlight
    // while its dropdown is open.
    property bool powerActive: false

    spacing: 12

    // ---- Search (left) ----
    SearchBar {
        id: searchBar
        Layout.fillWidth: true
        Layout.preferredHeight: 44

        onAccepted: root.searchAccepted()
        onEscapePressed: root.searchEscape()
        onUpPressed: root.searchUp()
        onDownPressed: root.searchDown()
    }

    // ---- Power button (right) ----
    Rectangle {
        id: powerBtn
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 6
        color: (powerHover.hovered || root.powerActive) ? Theme.hoverBg : "transparent"

        HoverHandler { id: powerHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.togglePowerMenu()
        }

        Image {
            anchors.centerIn: parent
            width: 22
            height: 22
            sourceSize.width: 36
            sourceSize.height: 36
            source: Qt.resolvedUrl("../../../icons/power.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }
}
