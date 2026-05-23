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

    // backing state
    property bool powered: false
    property var connected: []     // array of connected device names

    property var tooltip
    signal clicked()

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    function iconChar() {
        // Font Awesome 7 Brands: fa-bluetooth (U+F293). Brands ships in a
        // single style only, so the on/off distinction comes from opacity
        // (full when powered, dimmed when off) — same trick as before.
        return "";
    }

    function tooltipText() {
        if (!powered) return "Bluetooth Off";
        if (connected.length === 0) return "Bluetooth On";
        return "Bluetooth On - " + connected.join(", ");
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!tooltip) return;
            if (hovered) {
                var p = mapToItem(null, width / 2, 0);
                tooltip.show(root.tooltipText(), p.x, root);
            } else {
                tooltip.hide(root);
            }
        }
    }

    function refreshTooltip() {
        if (hover.hovered && tooltip) tooltip.text = root.tooltipText();
    }
    onPoweredChanged:   refreshTooltip()
    onConnectedChanged: refreshTooltip()

    Text {
        anchors.centerIn: parent
        text: root.iconChar()
        color: Theme.textPrimary
        opacity: root.powered ? 1.0 : 0.4
        font.family: "Font Awesome 7 Brands"
        font.pixelSize: 18
        renderType: Text.NativeRendering
    }

    // Tiny "connected" dot in the bottom-right corner when a device is paired
    // and active. Mirrors how the wifi icon goes solid only when connected.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 7
        anchors.bottomMargin: 6
        width: 6
        height: 6
        radius: 3
        color: Theme.barAccent
        visible: root.powered && root.connected.length > 0
    }

    // bluetoothctl is part of bluez and is the standard CLI on every distro
    // that has bluetooth, so it's the most portable signal.
    Timer {
        running: true
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

    // One shell hop: print "powered=yes/no", then one "conn=<name>" line
    // per currently-connected device.
    Process {
        id: query
        command: ["sh", "-c",
            "p=$(bluetoothctl show 2>/dev/null | awk '/^\\s*Powered:/ {print $2; exit}');"
            + "[ -z \"$p\" ] && p=no;"
            + "echo \"powered=$p\";"
            + "bluetoothctl devices Connected 2>/dev/null | awk '{$1=\"\"; $2=\"\"; sub(/^  /, \"\"); print \"conn=\" $0}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var names = [];
                var pow = false;
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    if (line.indexOf("powered=") === 0) {
                        pow = line.substring("powered=".length) === "yes";
                    } else if (line.indexOf("conn=") === 0) {
                        var n = line.substring("conn=".length).trim();
                        if (n.length > 0) names.push(n);
                    }
                }
                root.powered = pow;
                root.connected = names;
            }
        }
    }
}
