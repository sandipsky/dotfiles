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

    // Latest computed usage percentage (0..100).
    property real usage: 0
    property var tooltip

    // Previous /proc/stat snapshot — usage is a delta of these.
    property real _prevActive: -1
    property real _prevTotal: -1

    function tooltipText() { return "CPU: " + Math.round(usage) + "%"; }

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

    onUsageChanged: {
        if (hover.hovered && tooltip) tooltip.text = root.tooltipText();
    }

    Text {
        anchors.centerIn: parent
        // Font Awesome 7 Free Solid: fa-microchip (U+F2DB).
        text: ""
        color: Theme.textPrimary
        font.family: "Font Awesome 7 Free"
        font.styleName: "Solid"
        font.pixelSize: 17
        renderType: Text.NativeRendering
    }

    Timer {
        running: true
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuQuery.running = true
    }

    // /proc/stat first line: `cpu user nice system idle iowait irq softirq …`
    // Active = total - (idle + iowait). Usage is the active-fraction of the
    // delta between two consecutive samples.
    Process {
        id: cpuQuery
        command: ["sh", "-c",
            "awk '/^cpu / {idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print total-idle, total}' /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/);
                if (parts.length < 2) return;
                var active = parseFloat(parts[0]);
                var total  = parseFloat(parts[1]);
                if (isNaN(active) || isNaN(total)) return;

                if (root._prevTotal >= 0) {
                    var da = active - root._prevActive;
                    var dt = total  - root._prevTotal;
                    if (dt > 0) root.usage = Math.max(0, Math.min(100, (da / dt) * 100));
                }
                root._prevActive = active;
                root._prevTotal  = total;
            }
        }
    }
}
