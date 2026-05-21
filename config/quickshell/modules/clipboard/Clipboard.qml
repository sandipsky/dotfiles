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
        anchors.rightMargin: 8
        anchors.bottomMargin: 46

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
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 16
                    font.weight: Font.Bold
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
                        font.family: Theme.fontFamily
                        font.styleName: Theme.fontStyle
                        font.pixelSize: 15
                    }
                }
            }

            // ---------- History list ----------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
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
                            // Optimistic update: drop the row from the view
                            // right away so the click feels instant. The
                            // background `cliphist delete` catches up — we
                            // skip the refresh() because `cliphist list`
                            // would race ahead of the delete and re-add the
                            // row until the next refresh.
                            var id = entryId;
                            root.entries = root.entries.filter(function (e) {
                                return e.id !== id;
                            });
                            Quickshell.execDetached([
                                "sh", "-c",
                                "printf '" + id + "\\tx\\n' | cliphist delete"
                            ]);
                        }
                    }

                    // Empty-state placeholder
                    Text {
                        anchors.centerIn: parent
                        visible: root.entries.length === 0
                        text: "Clipboard history is empty"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.styleName: Theme.fontStyle
                        font.pixelSize: 16
                    }
                }

                // Interactive scrollbar: drag the thumb or click anywhere on
                // the track to jump. Width expands on hover for an easier
                // grab target. Mirrors the startmenu AppList scrollbar.
                Item {
                    id: scrollbar
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: scrollHover.hovered || scrollArea.pressed ? 12 : 6
                    visible: list.contentHeight > list.height

                    Behavior on width { NumberAnimation { duration: 120 } }

                    HoverHandler { id: scrollHover }

                    Item {
                        id: track
                        anchors.fill: parent
                    }

                    MouseArea {
                        id: scrollArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true

                        property real grabOffset: 0

                        function moveTo(localY) {
                            var maxThumbY = Math.max(0, track.height - thumb.height);
                            var maxContentY = Math.max(0, list.contentHeight - list.height);
                            if (maxThumbY <= 0 || maxContentY <= 0) return;
                            var newThumbY = Math.max(0, Math.min(maxThumbY, localY - grabOffset));
                            list.contentY = (newThumbY / maxThumbY) * maxContentY;
                        }

                        onPressed: (mouse) => {
                            if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                                grabOffset = mouse.y - thumb.y;
                            } else {
                                grabOffset = thumb.height / 2;
                                moveTo(mouse.y);
                            }
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) moveTo(mouse.y);
                        }
                    }

                    Rectangle {
                        id: thumb
                        x: 2
                        width: Math.max(0, scrollbar.width - 4)
                        radius: width / 2
                        color: scrollHover.hovered || scrollArea.pressed
                            ? "#6a6a6a"
                            : Theme.startmenuSearchBorder

                        readonly property real maxContentY: Math.max(1, list.contentHeight - list.height)
                        y: (list.contentY / maxContentY) * (track.height - height)
                        height: Math.max(30, track.height * Math.min(1, list.height / list.contentHeight))
                    }
                }
            }
        }
    }
}
