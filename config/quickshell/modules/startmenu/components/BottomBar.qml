import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../styles"

// Footer row: search field — transparent background.
RowLayout {
    id: root

    // Search signals/state, forwarded from the embedded SearchBar.
    signal searchAccepted()
    signal searchEscape()
    signal searchUp()
    signal searchDown()
    property alias searchText: searchBar.text
    function clearSearch() { searchBar.clear(); }
    function focusSearch() { searchBar.focusInput(); }

    spacing: 12

    // ---- Search ----
    SearchBar {
        id: searchBar
        Layout.fillWidth: true
        Layout.preferredHeight: 44

        onAccepted: root.searchAccepted()
        onEscapePressed: root.searchEscape()
        onUpPressed: root.searchUp()
        onDownPressed: root.searchDown()
    }
}
