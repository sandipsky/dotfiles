import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../styles"
import "components"

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool open: false
    visible: open

    function close() { open = false; }
    function refresh() { listProc.running = true; }

    onOpenChanged: if (open) refresh()

    // Each entry: { id: "5", preview: "hello world" }.
    // Backed by `cliphist list` — works on any Wayland compositor with
    // wl-clipboard installed (i.e. both Hyprland and Plasma 6).
    property var entries: []

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    if (!line) continue;
                    var tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    var preview = line.substring(tab + 1);
                    // cliphist marks non-text payloads (images, etc.) with
                    // a "[[ binary data … ]]" preview — drop those, the
                    // user only wants text history.
                    if (preview.indexOf("[[ binary") === 0) continue;
                    out.push({
                        id: line.substring(0, tab),
                        preview: preview
                    });
                }
                root.entries = out;
            }
        }
    }

    // Outside-click dismiss
    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    Rectangle {
        id: panel

        width: 400
        height: 460
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: 60

        color: Theme.calendarBg
        radius: Theme.calendarRadius
        border.color: Theme.calendarBorder
        border.width: 1
        clip: true

        // Soft drop shadow — same trick as the calendar panel.
        Repeater {
            parent: root
            model: 6
            delegate: Rectangle {
                anchors.fill: panel
                anchors.leftMargin:   -(index + 1)
                anchors.rightMargin:  -(index + 1)
                anchors.topMargin:    0
                anchors.bottomMargin: -(index + 1) - 2
                z: -1 - index
                color: "transparent"
                radius: panel.radius + (index + 1)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.18 / (index + 1))
            }
        }

        // Swallow inside-clicks so they don't reach the outside dismiss.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- Header: "Clipboard" + "Clear All" ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.calendarHeaderBg
                radius: Theme.calendarRadius

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: Theme.textPrimary
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: clearBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    width: clearText.implicitWidth + 24
                    radius: 6
                    color: clearHover.hovered ? Theme.hoverBg : "transparent"

                    HoverHandler { id: clearHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            Quickshell.execDetached(["cliphist", "wipe"]);
                            root.entries = [];
                        }
                    }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: Theme.textPrimary
                        font.pixelSize: 13
                    }
                }
            }

            // ---------- History list ----------
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.entries
                spacing: 2
                topMargin: 8
                bottomMargin: 8
                leftMargin: 8
                rightMargin: 8
                boundsBehavior: Flickable.StopAtBounds

                delegate: ClipboardItem {
                    width: list.width - list.leftMargin - list.rightMargin
                    entryId: modelData.id
                    preview: modelData.preview

                    onCopy: {
                        // cliphist decode reads its argument as a list entry,
                        // so prefix the bare id with a fake tab/preview to
                        // satisfy its parser.
                        Quickshell.execDetached([
                            "sh", "-c",
                            "cliphist decode " + entryId + " | wl-copy"
                        ]);
                        root.close();
                    }
                    onRemoveEntry: {
                        // cliphist delete reads list entries from stdin and
                        // only consumes the id before the tab — sending any
                        // line that starts with "<id>\t" is enough.
                        Quickshell.execDetached([
                            "sh", "-c",
                            "printf '" + entryId + "\\tx\\n' | cliphist delete"
                        ]);
                        root.refresh();
                    }
                }

                // Empty-state placeholder
                Text {
                    anchors.centerIn: parent
                    visible: root.entries.length === 0
                    text: "Clipboard history is empty"
                    color: Theme.textSecondary
                    font.pixelSize: 13
                }
            }
        }
    }
}
