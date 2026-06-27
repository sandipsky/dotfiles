import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../styles"
import "components"

PanelWindow {
    id: root

    // Full-screen layer-shell window. The actual menu lives inside as a
    // child Rectangle; the surrounding transparent area swallows
    // outside-clicks so they close the menu (Hyprland-friendly).
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool open: true
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible

    // Negative: the menu tucks up behind the top bar when hidden. Moving it
    // up by (menu.height + the top gap) lifts its bottom edge to the bar's
    // bottom edge — where the slideClip clips the rest away.
    readonly property real _hiddenOffset: -(menu.height + menu.anchors.topMargin)

    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            bottomBar.clearSearch();
            bottomBar.focusSearch();
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    function close() {
        open = false;
    }

    // Esc closes from anywhere in the window
    Keys.onEscapePressed: root.close()

    // ---------------- Outside-click dismiss ----------------
    MouseArea {
        id: outsideArea
        anchors.fill: parent
        onPressed: root.close()
    }

    // Clipping container: its top edge sits at the bottom of the bar so
    // anything above that line is cut off. Sliding the menu up through
    // this edge produces the "tuck behind the bar" effect, while the bar
    // (a separate layer-shell surface) continues to paint normally.
    Item {
        id: slideClip
        anchors.fill: parent
        anchors.topMargin: Theme.barHeight
        clip: true

    ClippingRectangle {
        id: menu
        width: 420
        height: 680
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 8

        color: Theme.startmenuBg
        radius: Theme.menuRadius
        border.color: Theme.startmenuBorder
        border.width: 1

        transform: Translate {
            id: slideTransform
            y: 0
        }

        NumberAnimation {
            id: slideInAnim
            target: slideTransform
            property: "y"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOutAnim
            target: slideTransform
            property: "y"
            to: root._hiddenOffset
            duration: 220
            easing.type: Easing.InCubic
            onFinished: root._renderVisible = false
        }

        Component.onCompleted: {
            if (root.open) {
                slideTransform.y = root._hiddenOffset;
                slideInAnim.restart();
            }
        }

        // Swallows any click inside the menu that wasn't handled by a
        // child handler so the outer outsideArea never sees it.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 24
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 12
            spacing: 24

            AppList {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                filter: bottomBar.searchText
                onAppLaunched: root.close()
            }

            BottomBar {
                id: bottomBar
                Layout.fillWidth: true

                onSearchAccepted: {
                    if (appList.entries.length > 0) {
                        appList.launchSelected();
                        root.close();
                    }
                }
                onSearchEscape: root.close()
                onSearchUp: appList.moveSelection(-1)
                onSearchDown: appList.moveSelection(1)
            }
        }

    }
    }
}
