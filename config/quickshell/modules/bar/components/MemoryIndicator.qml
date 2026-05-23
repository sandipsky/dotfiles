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

    property real usedGB: 0
    property real totalGB: 0
    property var tooltip

    function tooltipText() {
        if (totalGB <= 0) return "Memory: " + usedGB.toFixed(1) + " GB";
        return "Memory: " + usedGB.toFixed(1) + " GB / " + totalGB.toFixed(1) + " GB";
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
    onUsedGBChanged:  refreshTooltip()
    onTotalGBChanged: refreshTooltip()

    Text {
        anchors.centerIn: parent
        // Font Awesome 7 Free Solid: fa-memory (U+F538).
        text: ""
        color: Theme.textPrimary
        font.family: "Font Awesome 7 Free"
        font.styleName: "Solid"
        font.pixelSize: 17
        renderType: Text.NativeRendering
    }

    Timer {
        running: true
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: memQuery.running = true
    }

    // MemAvailable (kernel-reported "what's actually free for programs")
    // matches what `free -h` shows in the "available" column, so the GB
    // figure lines up with what users see elsewhere.
    Process {
        id: memQuery
        command: ["sh", "-c",
            "awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf \"%.2f %.2f\", (t-a)/1048576, t/1048576}' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/);
                if (parts.length < 2) return;
                var u = parseFloat(parts[0]);
                var t = parseFloat(parts[1]);
                if (!isNaN(u)) root.usedGB  = u;
                if (!isNaN(t)) root.totalGB = t;
            }
        }
    }
}
