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
    function refresh() { volumeQuery.running = true; }
    onOpenChanged: if (open) refresh()

    property real volume: 0.5
    property bool muted: false

    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    Rectangle {
        id: panel
        width: 320
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 46

        height: column.implicitHeight + 28

        color: Theme.calendarBg
        radius: Theme.calendarRadius
        border.color: Theme.calendarBorder
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 14
            spacing: 10

            SettingSlider {
                Layout.fillWidth: true
                // Segoe Fluent Icons: Mute E74F / Volume1..3 E993..E995.
                iconChar: root.muted                  ? "" :
                          root.volume * 100 < 1       ? "" :
                          root.volume * 100 < 34      ? ""  :
                          root.volume * 100 < 67      ? ""  :
                                                        ""
                minValue: 0
                maxValue: 1
                value: root.volume
                onValueDragged: (v) => {
                    root.volume = v;
                    Quickshell.execDetached([
                        "wpctl", "set-volume", "-l", "1.0",
                        "@DEFAULT_AUDIO_SINK@",
                        Math.round(v * 100) + "%"
                    ]);
                }
            }
        }
    }

    Process {
        id: volumeQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                root.muted = t.indexOf("[MUTED]") !== -1;
                var m = t.match(/Volume:\s*([0-9.]+)/);
                if (m) root.volume = parseFloat(m[1]);
            }
        }
    }
}
