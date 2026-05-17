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

    // Hide entirely when no battery is detected (desktops, VMs without a
    // virtual battery, etc.) so we don't render a permanently-empty icon.
    property bool present: false
    property int  percentage: 0
    property bool charging: false
    property string timeRemaining: ""   // e.g. "1hr 24min remaining" or ""
    property int  brightness: -1        // -1 = no backlight detected

    property var tooltip
    signal clicked()

    visible: present

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    function iconFile() {
        if (charging) return "bat-charge.svg";
        if (percentage <= 10) return "bat0.svg";
        if (percentage <= 30) return "bat1.svg";
        if (percentage <= 55) return "bat2.svg";
        if (percentage <= 80) return "bat3.svg";
        return "bat4.svg";
    }

    function tooltipText() {
        var line1 = percentage + "%";
        if (timeRemaining.length > 0) line1 += ": " + timeRemaining;
        var lines = [line1];
        if (brightness >= 0) lines.push("Brightness: " + brightness + "%");
        return lines.join("\n");
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

    // Refresh tooltip live while the cursor lingers and any of the
    // displayed values change (level rolls over, brightness slider moves,
    // etc.).
    function refreshTooltip() {
        if (hover.hovered && tooltip) tooltip.text = root.tooltipText();
    }
    onPercentageChanged:    refreshTooltip()
    onChargingChanged:      refreshTooltip()
    onTimeRemainingChanged: refreshTooltip()
    onBrightnessChanged:    refreshTooltip()

    Image {
        anchors.centerIn: parent
        width: 24
        height: 24
        sourceSize.width: 32
        sourceSize.height: 32
        source: Qt.resolvedUrl("../../../icons/" + root.iconFile())
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // sysfs is the cheapest, most portable source — works the same on
    // Plasma and Hyprland and doesn't depend on upower/dbus. The glob
    // covers BAT0 / BAT1 / etc; `head -1` keeps things sane if a system
    // exposes more than one battery.
    Timer {
        running: true
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            capQuery.running = true;
            statusQuery.running = true;
            timeQuery.running = true;
            brightnessQuery.running = true;
        }
    }

    Process {
        id: capQuery
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim();
                if (s.length > 0) {
                    var n = parseInt(s);
                    if (!isNaN(n)) {
                        root.percentage = n;
                        root.present = true;
                    }
                } else {
                    root.present = false;
                }
            }
        }
    }

    Process {
        id: statusQuery
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Treat any "plugged in" state as charging visually:
                //  - "Charging"     : actively pumping energy in
                //  - "Full"         : topped off but charger still connected
                //  - "Not charging" : plugged in, paused by a charge-threshold rule
                // Only "Discharging" (and the rare "Unknown") fall back to the
                // level icon.
                var status = text.trim();
                root.charging = (status === "Charging"
                              || status === "Full"
                              || status === "Not charging");
            }
        }
    }

    // upower exposes the time-remaining estimate already pre-formatted
    // (e.g. "2.4 hours" or "45 minutes"). Convert into a compact
    // "Xhr Ymin remaining" / "to full" string for the tooltip.
    Process {
        id: timeQuery
        command: ["sh", "-c",
            "upower -i $(upower -e 2>/dev/null | grep -m1 BAT) 2>/dev/null"
            + " | awk '/time to empty|time to full/ {sub(/^ +/, \"\"); print; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) { root.timeRemaining = ""; return; }
                // Example matches: "time to empty: 2.4 hours", "time to full: 45.0 minutes"
                var m = t.match(/time to (empty|full):\s*([0-9.]+)\s*(\w+)/);
                if (!m) { root.timeRemaining = ""; return; }
                var direction = m[1];   // "empty" or "full"
                var value = parseFloat(m[2]);
                var unit = m[3];
                var totalMin;
                if (unit.indexOf("hour") === 0)  totalMin = value * 60;
                else if (unit.indexOf("min") === 0) totalMin = value;
                else if (unit.indexOf("sec") === 0) totalMin = value / 60;
                else { root.timeRemaining = ""; return; }
                totalMin = Math.round(totalMin);
                var h = Math.floor(totalMin / 60);
                var mn = totalMin % 60;
                var pretty = (h > 0 ? h + "hr " : "") + (mn > 0 || h === 0 ? mn + "min" : "").trim();
                pretty = pretty.trim();
                root.timeRemaining = pretty + (direction === "full" ? " to full" : " remaining");
            }
        }
    }

    // Brightness pulled from sysfs — covers intel_backlight, amdgpu_bl0,
    // and friends via the glob. Output is rounded to a percentage.
    Process {
        id: brightnessQuery
        command: ["sh", "-c",
            "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1);"
            + "m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1);"
            + "[ -n \"$b\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ] && echo $((b * 100 / m))"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim();
                if (s.length === 0) { root.brightness = -1; return; }
                var n = parseInt(s);
                root.brightness = isNaN(n) ? -1 : n;
            }
        }
    }
}
