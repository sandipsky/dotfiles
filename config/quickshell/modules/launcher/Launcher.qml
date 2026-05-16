import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../styles"
import "components"

PanelWindow {
    id: root

    // Bind to one output — without this Hyprland creates the layer-shell
    // surface on every connected monitor, so the launcher renders twice.
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

    property bool open: true
    visible: open

    function close() { open = false; }

    Keys.onEscapePressed: root.close()

    // outside-click dismiss
    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    // Fake drop shadow — stacked rounded borders with decreasing opacity
    // and a slight downward bias. Avoids MultiEffect, which renders a
    // stray duplicate of the source on software-rendered GL stacks
    // (KDE-on-VirtualBox, llvmpipe, etc.).
    Repeater {
        model: 6
        delegate: Rectangle {
            anchors.fill: launcher
            anchors.leftMargin:   -(index + 1)
            anchors.rightMargin:  -(index + 1)
            anchors.topMargin:    0
            anchors.bottomMargin: -(index + 1) - 2
            z: -1 - index
            color: "transparent"
            radius: launcher.radius + (index + 1)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18 / (index + 1))
        }
    }

    Rectangle {
        id: launcher

        width: 640
        x: (parent.width - width) / 2
        y: parent.height * 0.20

        // Auto-grow: just the input at rest, expand to fit results.
        height: input.height + (results.visible ? results.height + 8 : 0)
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        color: Theme.launcherBg
        radius: Theme.launcherRadius
        border.color: Theme.launcherBorder
        border.width: 1
        clip: true

        // Eat any inside-click so it doesn't reach the outsideArea above.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        LauncherInput {
            id: input
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 60

            onAccepted: launcher.activateSelected()
            onEscapePressed: root.close()
            onTextChanged: results.selectedIndex = 0
            onUpRequested: results.moveSelection(-1)
            onDownRequested: results.moveSelection(+1)
        }

        // Thin separator between input and results
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: input.bottom
            height: 1
            color: Theme.launcherBorder
            visible: results.visible
        }

        LauncherResults {
            id: results
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: input.bottom
            anchors.topMargin: 8

            query: input.text
            visible: items.length > 0

            onActivated: (item) => launcher.executeItem(item)
        }

        function activateSelected() {
            if (results.items.length === 0) return;
            executeItem(results.items[results.selectedIndex] || results.items[0]);
        }

        function executeItem(item) {
            if (!item) return;
            if (item.type === "app") {
                if (item.entry && item.entry.execute) item.entry.execute();
            } else if (item.type === "calc") {
                Quickshell.execDetached(["sh", "-c", "printf %s " + JSON.stringify(item.result) + " | wl-copy"]);
            } else if (item.type === "google") {
                var url = "https://www.google.com/search?q=" + encodeURIComponent(item.query);
                Quickshell.execDetached(["xdg-open", url]);
            }
            root.close();
        }
    }
}
