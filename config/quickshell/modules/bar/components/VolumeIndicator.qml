import QtQuick
import Quickshell
import Quickshell.Io
import "../../../styles"

Rectangle {
    id: root
    width: 32
    height: 32
    radius: 6
    color: hover.hovered ? Theme.hoverBg : "transparent"

    // Cross-compositor: drive volume through WirePlumber's CLI, which is
    // the standard surface on both Hyprland and Plasma when PipeWire is
    // the audio server. If a system still ships PulseAudio only, swap
    // these commands for `pactl` equivalents.
    property real volume: 0     // 0.0 .. 1.0
    property bool muted: false

    function iconFile() {
        if (muted) return "vol-mute.svg";
        var pct = volume * 100;
        if (pct < 1)  return "vol-mute.svg";
        if (pct < 34) return "vol1.svg";
        if (pct < 67) return "vol2.svg";
        return "vol3.svg";
    }

    HoverHandler { id: hover }

    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            query.running = true;
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            // `-l 1.0` caps wpctl at 100% so scrolling can't push volume
            // above unity gain.
            if (event.angleDelta.y > 0)
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"]);
            else if (event.angleDelta.y < 0)
                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]);
            query.running = true;
        }
    }

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        sourceSize.width: 32
        sourceSize.height: 32
        source: Qt.resolvedUrl("../../../icons/" + root.iconFile())
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Poll for state. wpctl prints e.g. "Volume: 0.50" or
    // "Volume: 0.50 [MUTED]" on a single line.
    Timer {
        running: true
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }
    Process {
        id: query
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
