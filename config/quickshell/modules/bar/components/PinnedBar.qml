import QtQuick
import Quickshell
import "../../../styles"

// Centered row of pinned-app launchers. Backed by the PinnedApps service
// passed in from shell.qml. Left-click launches; right-click asks the
// owner (Bar.qml → shell.qml) to spawn the unpin context menu.
Row {
    id: root
    spacing: 4

    property var pinned: null
    property var tooltip: null

    // Emitted with the desktop-entry id and the screen-x of the icon
    // center, so the context-menu overlay can anchor under it.
    signal contextRequested(string id, int screenX)

    Repeater {
        model: root.pinned ? root.pinned.ids : []
        delegate: Rectangle {
            id: btn
            required property var modelData
            required property int index
            readonly property var entry: root.pinned ? root.pinned.entryById(modelData) : null

            visible: entry !== null
            width: visible ? 32 : 0
            height: 32
            radius: 6
            color: hover.hovered ? Theme.hoverBg : "transparent"

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (!root.tooltip) return;
                    if (hovered && btn.entry) {
                        var p = btn.mapToItem(null, btn.width / 2, 0);
                        root.tooltip.show(btn.entry.name || btn.modelData, p.x);
                    } else {
                        root.tooltip.hide();
                    }
                }
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: if (btn.entry && btn.entry.execute) btn.entry.execute()
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: {
                    if (root.tooltip) root.tooltip.hide();
                    var p = btn.mapToItem(null, btn.width / 2, 0);
                    root.contextRequested(btn.modelData, p.x);
                }
            }

            Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                sourceSize.width: 40
                sourceSize.height: 40
                source: btn.entry
                    ? Quickshell.iconPath(btn.entry.icon || "", "application-x-executable")
                    : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }
    }
}
