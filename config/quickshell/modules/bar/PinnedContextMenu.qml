import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../styles"

// Right-click "Unpin from taskbar" popup spawned by PinnedBar icons. Lives
// on the Overlay layer (same pattern as StartMenu) so it can paint above
// the bar even though the bar itself is anchored to the screen edge.
PanelWindow {
    id: root

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var pinned: null
    property string targetId: ""
    property int anchorX: 0
    property bool open: false
    visible: open

    function show(id, screenX) {
        targetId = id;
        anchorX = screenX;
        open = true;
    }
    function close() { open = false; }

    Keys.onEscapePressed: close()

    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    Rectangle {
        id: menu
        width: 180
        height: 40
        x: Math.max(8, Math.min(root.anchorX - width / 2, parent.width - width - 8))
        y: Theme.barHeight + 6

        color: Theme.dropdownBg
        border.color: Theme.dropdownBorder
        border.width: 1
        radius: 8

        // Swallow clicks inside the bubble so MouseArea above doesn't close it.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 4
            color: itemHover.hovered ? Theme.hoverBg : "transparent"
            HoverHandler { id: itemHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: {
                    if (root.pinned && root.targetId) root.pinned.unpin(root.targetId);
                    root.close();
                }
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: "Unpin from taskbar"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 14
            }
        }
    }
}
