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
    property var tooltip
    signal clicked()

    function tooltipText() {
        if (muted) return "Muted";
        return "Volume: " + Math.round(volume * 100) + "%";
    }

    function iconChar() {
        if (muted) return "\uE74F";
        var pct = volume * 100;
        if (pct < 1)  return "\uE74F";
        if (pct < 34) return "\uE993";
        if (pct < 67) return "\uE994";
        return "\uE995";
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!tooltip) return;
            if (hovered) {
                var p = mapToItem(null, width / 2, 0);
                tooltip.show(root.tooltipText(), p.x);
            } else {
                tooltip.hide();
            }
        }
    }

    // Refresh tooltip live while the cursor lingers and the volume changes.
    onVolumeChanged: if (hover.hovered && tooltip) tooltip.text = root.tooltipText()
    onMutedChanged:  if (hover.hovered && tooltip) tooltip.text = root.tooltipText()

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
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

    // Dim full-volume glyph sits underneath so the inactive arcs stay
    // visible as a faint outline behind the active level. Hidden while
    // muted — the mute icon shouldn't carry phantom arcs.
    Text {
        anchors.centerIn: parent
        visible: !root.muted
        text: "\uE995"
        color: Theme.textSecondary
        opacity: 0.35
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 18
        renderType: Text.NativeRendering
    }

    Text {
        anchors.centerIn: parent
        text: root.iconChar()
        color: Theme.textPrimary
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 18
        renderType: Text.NativeRendering
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
