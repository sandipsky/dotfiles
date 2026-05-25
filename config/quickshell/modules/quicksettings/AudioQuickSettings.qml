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
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible

    // Distance the panel must travel to be fully tucked behind the bar.
    readonly property real _hiddenOffset: panel.height + panel.anchors.bottomMargin

    function close() { open = false; }
    function refresh() { volumeQuery.running = true; }
    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            refresh();
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    property real volume: 0.5
    property bool muted: false

    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    // Clipping container: its bottom edge sits at the top of the bar so
    // anything past that line is cut off, producing the "tuck behind the
    // bar" slide. The bar (a separate layer-shell surface) keeps painting
    // normally over the clipped pixels.
    Item {
        id: slideClip
        anchors.fill: parent
        anchors.bottomMargin: Theme.barHeight
        clip: true

        Item {
            id: slideContent
            anchors.fill: parent
            transform: Translate { id: slideTransform; y: 0 }
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

    Rectangle {
        id: panel
        parent: slideContent
        width: 320
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 6

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
                showPercent: true
                onValueDragged: (v) => {
                    root.volume = v;
                    if (root.muted) {
                        root.muted = false;
                        Quickshell.execDetached([
                            "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"
                        ]);
                    }
                    Quickshell.execDetached([
                        "wpctl", "set-volume", "-l", "1.0",
                        "@DEFAULT_AUDIO_SINK@",
                        Math.round(v * 100) + "%"
                    ]);
                }
                onIconClicked: {
                    root.muted = !root.muted;
                    Quickshell.execDetached([
                        "wpctl", "set-mute",
                        "@DEFAULT_AUDIO_SINK@", "toggle"
                    ]);
                }
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
